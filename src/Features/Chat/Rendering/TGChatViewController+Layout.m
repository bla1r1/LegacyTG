#import "TGPerf.h"
#include <pthread.h>
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
	CGFloat tableW = self.table.bounds.size.width;
	if (tableW <= 0) tableW = TGMetricScreenWidth;
	CGFloat maxMediaW = TGMetricBubbleMaxContentWidthForTableWidth(tableW);
	CGFloat maxMediaH = floorf(maxMediaW * 1.15f);

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
			w = maxMediaW;
			h = maxMediaW * TGMetricMediaRatioLandscape;
		}
	}
	if (w <= 0 || h <= 0)
		return CGSizeZero;

	CGFloat scale = MIN(maxMediaW / w, maxMediaH / h);
	scale = MIN(scale, TGMetricScaleFull);
	CGFloat resultW = floorf(w * scale);
	CGFloat resultH = floorf(h * scale);

	// Enforce minimum media width so vertical images are not crushed into narrow slivers.
	CGFloat minMediaW = MIN(kBubbleMinW - TGDoubled(kMediaInset), maxMediaW);
	if (resultW < minMediaW && w > 0) {
		scale = minMediaW / w;
		resultW = minMediaW;
		resultH = MIN(maxMediaH, floorf(h * scale));
	}
	return CGSizeMake(resultW, resultH);
}

- (void)measureTextsOf:(NSArray *)messages then:(dispatch_block_t)then {
	static dispatch_queue_t queue;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		// Serial, so two pages never measure at once on one core; LOW, so it
		// runs before the sticker loops but after the main thread's frames.
		queue = dispatch_queue_create("tg.chat.measure", DISPATCH_QUEUE_SERIAL);
		dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
	});
	// The whole row layouts of the page, not only its texts: iOS 6 asks
	// reloadData for every row's height, and laying out what the text
	// measure left (captions at the bubble's width, stamps, previews) was
	// still ~10% of a chat's first scroll on the iPod touch 4. The inputs are
	// gathered here, on main, from the stores; TGMessageRowLayout itself
	// touches neither stores nor views. The run and album checks read
	// self.messages, so the page's grouping stands in for it within this
	// call and is put back before any run loop turn could show it the table.
	NSArray *grouped = [self groupedMessagesFromMessages:messages];
	NSArray *shown = self.messages;
	self.messages = grouped;
	NSMutableArray *ids = [NSMutableArray array];
	NSMutableArray *inputs = [NSMutableArray array];
	for (NSInteger row = 0; row < (NSInteger)grouped.count; row++) {
		NSDictionary *m = grouped[(NSUInteger)row];
		NSNumber *msgId = m[@"id"];
		if (![msgId isKindOfClass:NSNumber.class])
			continue;
		BOOL runStart = [self runStartsAtRow:row];
		BOOL runEnd = [self runEndsAtRow:row];
		TGMessageLayout *hit = self.layoutCache[msgId];
		if (hit && hit.runStart == runStart && hit.runEnd == runEnd)
			continue;
		TGMessageRowInput *input = [self rowInputForMessage:m atRow:row runStart:runStart runEnd:runEnd];
		if (input.senderLineWidth) {
			// The sender's width asks the stores: answered now, here.
			CGFloat width = input.senderLineWidth(TGMessageSenderLine(input.senderName, m));
			input.senderLineWidth = ^CGFloat(NSString *line) { return width; };
		}
		[ids addObject:msgId];
		[inputs addObject:input];
	}
	self.messages = shown;
	if (!inputs.count) {
		then();
		if (self.messages.count)
			[self prefetchBodyTextsAroundRow:(NSInteger)self.messages.count - 1];
		return;
	}
	dispatch_async(queue, ^{
		pthread_setname_np("tg.chat-layout");
		double start = TGPerfNow();
		NSMutableArray *layouts = [NSMutableArray arrayWithCapacity:inputs.count];
		for (TGMessageRowInput *input in inputs)
			[layouts addObject:TGMessageRowLayout(input)];
		TGPerfReport("chat layouts", "background", start, 100.0);
		dispatch_async(dispatch_get_main_queue(), ^{
			for (NSUInteger i = 0; i < layouts.count; i++) {
				TGMessageLayout *layout = layouts[i];
				// The unread bar moves as the chat is read: never cached. A
				// row the table laid out meanwhile keeps its own.
				if (!layout.isUnreadSeparator && !self.layoutCache[ids[i]])
					self.layoutCache[ids[i]] = layout;
			}
			then();
			if (self.messages.count)
				[self prefetchBodyTextsAroundRow:(NSInteger)self.messages.count - 1];
		});
	});
}

/// What TGMessageRowLayout needs for this row, gathered on the main thread
/// from the stores and the message list; the layout itself touches neither.
- (TGMessageRowInput *)rowInputForMessage:(NSDictionary *)m atRow:(NSInteger)row
								 runStart:(BOOL)runStart runEnd:(BOOL)runEnd {
	NSNumber *msgId = m[@"id"];
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

	return input;
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
	TGMessageRowInput *input = [self rowInputForMessage:m atRow:row runStart:runStart runEnd:runEnd];
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
	NSArray *messages = self.messages;
	NSInteger row = indexPath.row;
	NSUInteger count = messages.count;
	CGFloat width = self.table.bounds.size.width;
	CGFloat fontSize = [TGTheme shared].messageFontSize;
	NSUInteger generation = self.layoutCache.generation;
	if (self.heightsMessages != messages || self.heightsGeneration != generation ||
			self.heightsWidth != width || self.heightsFontSize != fontSize ||
			self.rowHeights.length != count * sizeof(CGFloat)) {
		self.rowHeights = [NSMutableData dataWithLength:count * sizeof(CGFloat)];
		self.heightsMessages = messages;
		self.heightsGeneration = generation;
		self.heightsWidth = width;
		self.heightsFontSize = fontSize;
	}
	CGFloat *heights = (CGFloat *)self.rowHeights.mutableBytes;
	if (row < 0 || (NSUInteger)row >= count)
		return TGMetricZero;
	if (heights[row] > TGMetricZero)
		return heights[row];
	TGMessageLayout *layout = [self layoutForMessage:messages[row] atRow:row];
	CGFloat height = layout.rowHeight + [self runHeightChangeAtRow:row layout:layout];
	// A layout computed just now may have replaced a stale one (its run
	// changed): the heights measured before it are against the old cache.
	if (self.layoutCache.generation != generation)
		return height;
	heights[row] = height;
	return height;
}

@end
