#import "TGPerf.h"
#import "TGLocalization.h"
#import "TGChatViewControllerInternal.h"
#import "TGNameWithStatus.h"
#import "TGCapabilities.h"
#import "TGStyle.h"
#import "TGDevShowcase.h"
#import "TGPollPresentation.h"
#import "TGPinnedLine.h"
#import "TGUIFormat.h"
#import "TGMessageRowLayout.h"

#import "TGBase64.h"

UIColor *TGSenderColour(int64_t userId) {
	// The colour the person picked in their own profile, as Telegram draws it;
	// the id-based slot of their placeholder avatar until their record is here.
	return [[TGMessageStore shared] nameColourForUser:userId];
}

@implementation TGChatViewController (Layout)

#pragma mark - geometry

/// Finds the replied message dictionary if already loaded in quotes or messages.
- (NSDictionary *)repliedMessageFor:(NSDictionary *)m {
	NSNumber *replyId = m[@"replyId"];
	if (![replyId isKindOfClass:NSNumber.class])
		return nil;
	int64_t rid = [replyId longLongValue];
	if (rid == 0)
		return nil;
	NSDictionary *fetched = self.quotes[replyId];
	if (fetched)
		return fetched;
	for (NSDictionary *candidate in self.messages) {
		if ([candidate isKindOfClass:NSDictionary.class] && [candidate[@"id"] longLongValue] == rid) {
			return candidate;
		}
	}
	return nil;
}

- (int64_t)quoteAuthorStatusIdFor:(NSDictionary *)m {
	NSNumber *replyId = [m[@"replyId"] isKindOfClass:NSNumber.class] ? m[@"replyId"] : nil;
	if (!replyId)
		return 0;
	NSDictionary *original = [self repliedMessageFor:m];
	if (!original || [original[@"outgoing"] boolValue])
		return 0;
	int64_t senderId = [original[@"senderId"] longLongValue];
	return [[TGMessageStore shared] emojiStatusIdForUser:senderId];
}

/// Configures forwarded message attribution header and returns its height.
- (CGFloat)layoutForwardIn:(TGBubbleCell *)cell
				   message:(NSDictionary *)m
					 width:(CGFloat)width
{
	NSString *from = m[@"forward"];
	if (![from length]){
		cell.forwardLabel.hidden = YES;
		return 0;
	}

	TGTheme *theme = [TGTheme shared];
	cell.forwardLabel.hidden = NO;
	CGFloat topY = kPadV;
	if (self.isGroup && ![m[@"outgoing"] boolValue]) {
		topY += TGMetricSenderLineHeight;
	}
	cell.forwardLabel.frame = CGRectMake(kPadH, topY, width - TGDoubled(kPadH), TGMetricSenderLineHeight);

	int64_t forwardStatusId = 0;
	id forwardUid = m[@"forwardUserId"] ?: m[@"forwardSenderId"];
	if ([forwardUid respondsToSelector:@selector(longLongValue)]) {
		forwardStatusId = [[TGMessageStore shared] emojiStatusIdForUser:[forwardUid longLongValue]];
	}
	if (forwardStatusId == 0) {
		id forwardCid = m[@"forwardChatId"];
		if ([forwardCid respondsToSelector:@selector(longLongValue)]) {
			forwardStatusId = [[TGMessageStore shared] emojiStatusIdForChat:[forwardCid longLongValue]];
		}
	}
	if ([cell.forwardLabel respondsToSelector:@selector(setAttributedText:)]){
		NSString *line = TGForwardHeaderLine(from, m[@"forwardPsa"]);
		NSMutableAttributedString *styled =
				[[NSMutableAttributedString alloc] initWithString:line
													   attributes:@{
					NSForegroundColorAttributeName: [theme secondaryTextColour],
					NSFontAttributeName: cell.forwardLabel.font ?: TGFontMeta()
				}];
		NSRange nameRange = [line rangeOfString:from options:NSBackwardsSearch];
		if (nameRange.location != NSNotFound){
			NSAttributedString *name = TGNameWithStatus(from, forwardStatusId,
					TGFontMetaStrong(), [theme accentColour]);
			[styled replaceCharactersInRange:nameRange withAttributedString:name];
		}
		cell.forwardLabel.attributedText = styled;
	} else {
		cell.forwardLabel.textColor = [theme accentColour];
		cell.forwardLabel.text = TGForwardHeaderLine(from, m[@"forwardPsa"]);
	}
	return TGMetricQuoteForwardLine;
}

/// The service line as drawn: who acted, and for a pin, the quoted message
/// once it is loaded. The service text is made in Core, which cannot see the
/// chat's messages, so the quote is added here at display time.
- (NSString *)serviceLineForMessage:(NSDictionary *)m {
	NSString *who = m[@"separator"] ? nil
			: [[TGMessageStore shared] nameForUserId:[m[@"senderId"] longLongValue]];
	return TGMessageServiceLine(m, who, self.messages);
}

UIImage *TGImageFromMinithumbnail(id mini) {
	NSData *data = nil;
	if ([mini isKindOfClass:NSData.class]) {
		data = (NSData *)mini;
	} else if ([mini isKindOfClass:NSDictionary.class]) {
		NSString *b64 = mini[@"data"];
		if ([b64 isKindOfClass:NSString.class] && b64.length)
			data = TGBase64Decode(b64);
	} else if ([mini isKindOfClass:NSString.class]) {
		data = TGBase64Decode((NSString *)mini);
	}
	if (data.length) {
		return [UIImage imageWithData:data];
	}
	return nil;
}

- (UIImage *)imageFor:(NSDictionary *)m {
	UIImage *map = self.maps[m[@"id"]];
	if (map)
		return map;
	if ([m[@"paidPreview"] boolValue]) {
		NSNumber *msgId = m[@"id"];
		if ([msgId isKindOfClass:NSNumber.class]) {
			UIImage *cached = self.images[msgId];
			if (cached)
				return cached;
		}
		id mini = nil;
		NSDictionary *paid = m[@"paidMedia"];
		if ([paid isKindOfClass:NSDictionary.class]) {
			NSArray *items = paid[@"items"];
			if ([items isKindOfClass:NSArray.class] && items.count > 0 && [items[0] isKindOfClass:NSDictionary.class]) {
				mini = items[0][@"minithumbnail"];
			}
		}
		if (!mini) {
			mini = m[@"minithumbnail"];
		}
		UIImage *decoded = TGImageFromMinithumbnail(mini);
		if (decoded) {
			if ([msgId isKindOfClass:NSNumber.class]) {
				self.images[msgId] = decoded;
			}
			return decoded;
		}
	}
	NSNumber *fileId = m[@"photoId"];
	if ([fileId isKindOfClass:NSNumber.class]) {
		UIImage *cached = self.images[fileId];
		if (cached)
			return cached;
#if TG_DEV
		if (fileId.longLongValue < 0 || TGIsDevChat(self.chatId)) {
			UIImage *fixture = [TGDevShowcase imageForPhotoId:fileId.longLongValue];
			if (fixture)
				return fixture;
		}
#endif
	}
	return nil;
}

- (CGSize)imageSizeFor:(NSDictionary *)m {
	CGFloat w = 0, h = 0;
	if ([m[@"paidPreview"] boolValue] && [m[@"mediaWidth"] floatValue] > 0 && [m[@"mediaHeight"] floatValue] > 0) {
		w = [m[@"mediaWidth"] floatValue];
		h = [m[@"mediaHeight"] floatValue];
	} else {
		UIImage *img = [self imageFor:m];
		if (img) {
			w = img.size.width;
			h = img.size.height;
		} else if ([m[@"mediaWidth"] floatValue] > 0 && [m[@"mediaHeight"] floatValue] > 0) {
			w = [m[@"mediaWidth"] floatValue];
			h = [m[@"mediaHeight"] floatValue];
		} else if ([m[@"photoId"] isKindOfClass:NSNumber.class]) {
			w = kImageMax;
			h = kImageMax * TGMetricMediaRatioLandscape;
		}
	}
	if (w <= 0 || h <= 0)
		return CGSizeZero;

	CGFloat scale = MIN(kImageMax / w, kImageMax / h);
	scale = MIN(scale, TGMetricScaleFull);
	return CGSizeMake(floorf(w * scale), floorf(h * scale));
}

- (TGMessageLayout *)layoutForMessage:(NSDictionary *)m atRow:(NSInteger)row {
	NSNumber *msgId = m[@"id"];
	BOOL runStart = [self runStartsAtRow:row];
	BOOL runEnd = [self runEndsAtRow:row];
	if (msgId) {
		TGMessageLayout *hit = self.layoutCache[msgId];
		// Loading older or newer history re-groups the whole array, so a
		// message that opened a run can end up in the middle of one. Its
		// height moves with the run gap while its cached frames do not, and
		// the two drift apart into bubbles that overlap their neighbours.
		if (hit && hit.runStart == runStart && hit.runEnd == runEnd)
			return hit;
	}
	double layoutStart = TGPerfNow();
	BOOL mine = [m[@"outgoing"] boolValue];

	// The one thing measuring used to leave behind: the map card a location
	// row draws, made once per message.
	NSNumber *lat = m[@"lat"], *lon = m[@"lon"];
	if (TGMessageIsLocation(m) && ![m[@"service"] boolValue] &&
			[lat isKindOfClass:NSNumber.class] && [lon isKindOfClass:NSNumber.class] &&
			!self.maps[msgId])
		self.maps[msgId] = [self mapCardForLatitude:lat.doubleValue longitude:lon.doubleValue];

	TGMessageRowInput *input = [[TGMessageRowInput alloc] init];
	input.message = m;
	input.tableWidth = self.table.bounds.size.width;
	input.fontSize = [TGTheme shared].messageFontSize;
	input.runStart = runStart;
	input.runEnd = runEnd;
	input.continuesAlbum = [self continuesAlbumAtRow:row];
	input.isGroup = self.isGroup;
	if (TGMessageRowWantsCard(m))
		input.card = TGChatCardForRow(m);
	input.imageSize = [self imageSizeFor:m];
	NSDictionary *replied = [self repliedMessageFor:m];
	input.replied = replied;
	input.quoteAuthor = TGMessageQuoteAuthor(replied, replied
			? [[TGMessageStore shared] nameForUserId:[replied[@"senderId"] longLongValue]] : nil);
	if (self.isGroup && !mine) {
		int64_t senderId = [m[@"senderId"] longLongValue];
		input.senderName = [[TGMessageStore shared] nameForUserId:senderId];
		__weak typeof(self) weakSelf = self;
		CGFloat boost = TGMessageBoostBadgeWidth(m);
		input.senderLineWidth = ^CGFloat(NSString *line){
			return [weakSelf senderLineWidthFor:line
					statusId:[[TGMessageStore shared] emojiStatusIdForUser:senderId]] + boost;
		};
	}
	if ([m[@"service"] boolValue] && !m[@"separator"])
		input.serviceWho = [[TGMessageStore shared] nameForUserId:[m[@"senderId"] longLongValue]];
	input.messages = self.messages;
	input.pendingVotes = self.pendingPollVotes[@([msgId longLongValue])];
	input.animatedStickerReady = [TGCapabilities canPlayAnimatedStickers] &&
			self.lottiePaths[m[@"docId"]] != nil;

	TGMessageLayout *layout = TGMessageRowLayout(input);
	// A slow row names its kind, so scrolling or the initial burst can be
	// associated with what exactly measured heavy.
	NSString *kind = m[@"kind"];
	TGPerfReport("layout", kind.length ? [kind UTF8String] : "?", layoutStart, 20.0);
	// The unread bar is never cached: it moves as the chat is read.
	if (msgId && !layout.isUnreadSeparator)
		self.layoutCache[msgId] = layout;
	return layout;
}

/// The sender line as the bubble draws it, emoji status included once the
/// store has its picture.
- (CGFloat)senderLineWidthFor:(NSString *)line statusId:(int64_t)statusId {
	if (!line.length)
		return 0;
	NSAttributedString *styled = TGNameWithStatus(line, statusId, TGFontMetaStrong(), nil);
	CGFloat width = TGTextSize(line, TGFontMetaStrong(), 0).width;
	if (styled.length > 0 && [styled respondsToSelector:@selector(boundingRectWithSize:options:context:)]) {
		CGRect r = [styled boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, TGMetricSenderLineHeight)
										options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
										context:nil];
		width = ceilf(r.size.width);
	}
	return width;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *m = self.messages[indexPath.row];
	TGMessageLayout *layout = [self layoutForMessage:m atRow:indexPath.row];
	return layout.rowHeight + [self runHeightChangeAtRow:indexPath.row layout:layout];
}

@end
