#import "TGClient+FeatureSupport.h"
#import "TGClientInternal.h"

#pragma mark - small helpers

NSDictionary *TGFeatureDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

NSArray *TGFeatureArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : @[];
}

NSString *TGFeatureString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

NSString *TGFeatureErrorText(NSDictionary *result) {
	NSString *message = result[@"message"];
	return [message isKindOfClass:NSString.class] && message.length
			? message : @"An error occurred.";
}

BOOL TGFeatureOK(NSDictionary *result) {
	return ![result[@"@type"] isEqualToString:@"error"];
}

/// A formattedText's string, or nil when the object is not one. Used for the
/// request side, where an empty string is a real answer and nil must become
/// a JSON null.
NSString *TGFeatureFormattedTextValue(id value) {
	NSDictionary *text = TGFeatureDict(value);
	if (![text[@"@type"] isEqualToString:@"formattedText"])
		return nil;
	return TGFeatureString(text[@"text"]);
}

NSNumber *TGFeaturePhotoFileId(id photo) {
	NSDictionary *info = TGFeatureDict(photo);
	NSNumber *fileId = info[@"big"][@"id"];
	if ([fileId isKindOfClass:NSNumber.class])
		return fileId;
	fileId = info[@"small"][@"id"];
	if ([fileId isKindOfClass:NSNumber.class])
		return fileId;
	// communityFullInfo carries a chatPhoto, which has sizes instead.
	NSArray *sizes = info[@"sizes"];
	if ([sizes isKindOfClass:NSArray.class] && sizes.count){
		NSDictionary *largest = nil;
		for (NSDictionary *size in sizes){
			if (![size isKindOfClass:NSDictionary.class])
				continue;
			if (!largest ||
				[size[@"width"] doubleValue] > [largest[@"width"] doubleValue])
				largest = size;
		}
		fileId = largest[@"photo"][@"id"];
		if ([fileId isKindOfClass:NSNumber.class])
			return fileId;
	}
	return nil;
}

NSString *TGFeatureCommunityStatus(NSDictionary *status) {
	NSString *type = status[@"@type"];
	if ([type isEqualToString:@"communityMemberStatusCreator"])
		return @"Owner";
	if ([type isEqualToString:@"communityMemberStatusAdministrator"])
		return @"Administrator";
	if ([type isEqualToString:@"communityMemberStatusBanned"])
		return @"Banned";
	if ([type isEqualToString:@"communityMemberStatusLeft"])
		return @"Not a member";
	return @"Member";
}

/// chat_id → title, read from the chat rows the client already holds. A
/// community chat may not be in the list yet; the id stands in then.
NSString *TGFeatureChatTitle(int64_t chatId) {
	return [[TGClient shared] titleForChat:chatId];
}

NSArray *TGFeatureMessagesFromResult(NSDictionary *result) {
	// quickReplyMessage and quickReplyMessages answer with one or many; the
	// send path answers a Messages object.
	NSString *type = result[@"@type"];
	NSArray *raw = nil;
	if ([type isEqualToString:@"quickReplyMessage"])
		raw = @[result];
	else if ([type isEqualToString:@"quickReplyMessages"])
		raw = TGFeatureArray(result[@"messages"]);
	else if ([type isEqualToString:@"messages"])
		raw = TGFeatureArray(result[@"messages"]);
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *message in raw){
		if (![message isKindOfClass:NSDictionary.class])
			continue;
		NSDictionary *flat = TGFlattenMessage(message);
		[out addObject:@{
			@"id"      : flat[@"id"] ?: @(0),
			@"text"    : flat[@"text"] ?: @"",
			@"kind"    : flat[@"kind"] ?: @"",
			@"photoId" : flat[@"photoId"] ?: [NSNull null],
		}];
	}
	return out;
}

NSString *TGFeatureSuggestedState(NSString *type) {
	if ([type isEqualToString:@"suggestedPostStatePending"])
		return @"Pending";
	if ([type isEqualToString:@"suggestedPostStateApproved"])
		return @"Approved";
	if ([type isEqualToString:@"suggestedPostStateDeclined"])
		return @"Declined";
	return @"Unknown";
}

NSString *TGFeatureSuggestedPrice(NSDictionary *price) {
	NSString *type = price[@"@type"];
	if ([type isEqualToString:@"suggestedPostPriceStar"])
		return [NSString stringWithFormat:@"%lld stars",
				(long long)[price[@"star_count"] longLongValue]];
	if ([type isEqualToString:@"suggestedPostPriceGram"])
		return [NSString stringWithFormat:@"%lld Gram",
				(long long)[price[@"gram_cent_count"] longLongValue]];
	return @"Free";
}

NSString *TGFeatureActionKey(NSDictionary *action) {
	NSString *type = TGFeatureString(action[@"@type"]);
	if ([type isEqualToString:@"suggestedActionCustom"])
		return [type stringByAppendingFormat:@":%@", TGFeatureString(action[@"name"])];
	if ([type isEqualToString:@"suggestedActionConvertToBroadcastGroup"])
		return [type stringByAppendingFormat:@":%@", action[@"supergroup_id"] ?: @0];
	return type;
}

NSString *TGFeatureActionTitle(NSDictionary *action) {
	if ([TGFeatureString(action[@"@type"]) isEqualToString:@"suggestedActionCustom"]){
		NSString *name = TGFeatureString(action[@"name"]);
		if (name.length)
			return name;
	}
	NSString *type = TGFeatureString(action[@"@type"]);
	if ([type hasPrefix:@"suggestedAction"])
		type = [type substringFromIndex:@"suggestedAction".length];
	NSMutableString *out = [NSMutableString string];
	for (NSUInteger i = 0; i < type.length; i++){
		unichar c = [type characterAtIndex:i];
		if (i > 0 && c >= 'A' && c <= 'Z')
			[out appendString:@" "];
		[out appendFormat:@"%C", c];
	}
	return out.length ? out : @"Suggested Action";
}


#pragma mark - shared shapes

/// richText is a tree; headings, links and bold wrap one more level, so the
/// leaf's text is what every caller wants.
NSString *TGFeatureRichTextPlain(id value) {
	NSDictionary *text = TGFeatureDict(value);
	NSString *type = TGFeatureString(text[@"@type"]);
	if ([type isEqualToString:@"richTextPlain"])
		return TGFeatureString(text[@"text"]);
	if ([type isEqualToString:@"richTextCustomEmoji"]){
		NSString *alternative = TGFeatureString(text[@"alternative_text"]);
		return alternative.length ? alternative : @"";
	}
	if ([type isEqualToString:@"richTextUrl"]){
		NSString *label = TGFeatureRichTextPlain(text[@"text"]);
		return label.length ? label : TGFeatureString(text[@"url"]);
	}
	if ([type isEqualToString:@"richTextEmailAddress"]){
		NSString *label = TGFeatureRichTextPlain(text[@"text"]);
		return label.length ? label : TGFeatureString(text[@"email_address"]);
	}
	if ([type isEqualToString:@"richTextPhoneNumber"]){
		NSString *label = TGFeatureRichTextPlain(text[@"text"]);
		return label.length ? label : TGFeatureString(text[@"phone_number"]);
	}
	if ([type isEqualToString:@"richTextAnchor"] || [type isEqualToString:@"richTextAnchorLink"] ||
		[type isEqualToString:@"richTextReference"] || [type isEqualToString:@"richTextReferenceLink"] ||
		[type isEqualToString:@"richTextMention"] || [type isEqualToString:@"richTextHashtag"] ||
		[type isEqualToString:@"richTextCashtag"] || [type isEqualToString:@"richTextBotCommand"] ||
		[type isEqualToString:@"richTextBankCardNumber"] || [type isEqualToString:@"richTextTonAddress"] ||
		[type isEqualToString:@"richTextFixed"] || [type isEqualToString:@"richTextBold"] ||
		[type isEqualToString:@"richTextItalic"] || [type isEqualToString:@"richTextUnderline"] ||
		[type isEqualToString:@"richTextStrikethrough"] || [type isEqualToString:@"richTextSpoiler"] ||
		[type isEqualToString:@"richTextSubscript"] || [type isEqualToString:@"richTextSuperscript"] ||
		[type isEqualToString:@"richTextMarked"] ||
		[type isEqualToString:@"richTextDateTime"]){
		return TGFeatureRichTextPlain(text[@"text"]);
	}
	if ([type isEqualToString:@"richTextMathematicalExpression"])
		return TGFeatureString(text[@"expression"]);
	// A shape this client cannot read still often has a label somewhere.
	NSString *leaf = TGFeatureRichTextPlain(text[@"text"]);
	return leaf;
}

void TGFeatureFlattenBlocks(NSArray *blocks, NSMutableArray *lines);

NSString *TGFeaturePageBlockText(NSDictionary *block) {
	NSString *type = TGFeatureString(block[@"@type"]);
	if ([type isEqualToString:@"pageBlockParagraph"] ||
		[type isEqualToString:@"pageBlockSectionHeading"] ||
		[type isEqualToString:@"pageBlockPreformatted"] ||
		[type isEqualToString:@"pageBlockFooter"] ||
		[type isEqualToString:@"pageBlockThinking"]){
		return TGFeatureRichTextPlain(block[@"text"]);
	}
	if ([type isEqualToString:@"pageBlockMathematicalExpression"])
		return TGFeatureString(block[@"expression"]);
	if ([type isEqualToString:@"pageBlockDivider"])
		return @"—";
	if ([type isEqualToString:@"pageBlockAnchor"])
		return @"";
	if ([type isEqualToString:@"pageBlockPhoto"] || [type isEqualToString:@"pageBlockVideo"] ||
		[type isEqualToString:@"pageBlockAnimation"] || [type isEqualToString:@"pageBlockAudio"] ||
		[type isEqualToString:@"pageBlockVoiceNote"] || [type isEqualToString:@"pageBlockDocument"] ||
		[type isEqualToString:@"pageBlockMap"]){
		return TGFeatureRichTextPlain(TGFeatureDict(block[@"caption"])[@"text"]);
	}
	return @"";
}

void TGFeatureFlattenBlocks(NSArray *blocks, NSMutableArray *lines) {
	for (NSDictionary *block in blocks){
		if (![block isKindOfClass:NSDictionary.class])
			continue;
		NSString *type = TGFeatureString(block[@"@type"]);
		if ([type isEqualToString:@"pageBlockList"]){
			for (NSDictionary *item in TGFeatureArray(block[@"items"])){
				NSMutableArray *itemLines = [NSMutableArray array];
				TGFeatureFlattenBlocks(TGFeatureArray(item[@"blocks"]), itemLines);
				BOOL checked = [item[@"is_checked"] boolValue];
				NSString *marker = [item[@"has_checkbox"] boolValue] ? (checked ? @"☑ " : @"☐ ") : @"• ";
				NSString *body = [itemLines componentsJoinedByString:@"\n"];
				[lines addObject:[marker stringByAppendingString:body]];
			}
			continue;
		}
		if ([type isEqualToString:@"pageBlockBlockQuote"] ||
			[type isEqualToString:@"pageBlockExpandableBlockQuote"] ||
			[type isEqualToString:@"pageBlockCollage"] ||
			[type isEqualToString:@"pageBlockSlideshow"] ||
			[type isEqualToString:@"pageBlockDetails"]){
			NSMutableArray *inner = [NSMutableArray array];
			TGFeatureFlattenBlocks(TGFeatureArray(block[@"blocks"]), inner);
			if ([type isEqualToString:@"pageBlockBlockQuote"] ||
				[type isEqualToString:@"pageBlockExpandableBlockQuote"] ||
				[type isEqualToString:@"pageBlockDetails"]){
				NSString *credit = TGFeatureRichTextPlain(block[@"credit"]);
				if (!credit.length)
					credit = TGFeatureRichTextPlain(block[@"header"]);
				if (credit.length)
					[inner addObject:credit];
			}
			if (inner.count)
				[lines addObject:[inner componentsJoinedByString:@"\n"]];
			continue;
		}
		if ([type isEqualToString:@"pageBlockPullQuote"]){
			NSString *quote = TGFeatureRichTextPlain(block[@"text"]);
			NSString *credit = TGFeatureRichTextPlain(block[@"credit"]);
			if (credit.length)
				quote = [quote stringByAppendingFormat:@"\n%@", credit];
			if (quote.length)
				[lines addObject:quote];
			continue;
		}
		if ([type isEqualToString:@"pageBlockTable"]){
			for (NSArray *row in TGFeatureArray(block[@"cells"])){
				NSMutableArray *cells = [NSMutableArray array];
				for (NSDictionary *cell in TGFeatureArray(row)){
					NSString *text = TGFeatureRichTextPlain(cell[@"text"]);
					if (text.length)
						[cells addObject:text];
				}
				if (cells.count)
					[lines addObject:[cells componentsJoinedByString:@" | "]];
			}
			continue;
		}
		NSString *text = TGFeaturePageBlockText(block);
		if (text.length)
			[lines addObject:text];
	}
}


@implementation TGClient (FeatureSupport)

+ (NSDictionary *)inputRichMessageWithText:(NSString *)text {
	NSString *body = text ?: @"";
	NSMutableArray *blocks = [NSMutableArray array];
	// One paragraph per line: a rich editor is not what this is, and folding
	// a newline into a paragraph would lose the line break Telegram draws.
	NSArray *lines = [body componentsSeparatedByString:@"\n"];
	for (NSString *line in lines){
		[blocks addObject:@{
			@"@type" : @"inputPageBlockParagraph",
			@"text"  : @{@"@type" : @"richTextPlain",
						 @"text"  : line ?: @""},
		}];
	}
	if (!blocks.count){
		[blocks addObject:@{
			@"@type" : @"inputPageBlockParagraph",
			@"text"  : @{@"@type" : @"richTextPlain", @"text" : @""},
		}];
	}
	return @{
		@"@type" : @"inputRichMessage",
		@"source": @{
			@"@type" : @"richMessageSourceBlocks",
			@"blocks": blocks,
		},
		@"is_rtl"                : @NO,
		@"detect_automatic_blocks": @YES,
	};
}

+ (NSString *)plainTextFromRichMessage:(NSDictionary *)richMessage {
	NSMutableArray *lines = [NSMutableArray array];
	TGFeatureFlattenBlocks(TGFeatureArray(TGFeatureDict(richMessage)[@"blocks"]), lines);
	return [lines componentsJoinedByString:@"\n"];
}

+ (NSDictionary *)inputChecklistWithTitle:(NSString *)title
                                    tasks:(NSArray *)tasks
                              othersCanAdd:(BOOL)othersCanAdd
                             othersCanMark:(BOOL)othersCanMark {
	NSMutableArray *input = [NSMutableArray array];
	for (NSDictionary *task in tasks){
		if ([task isKindOfClass:NSDictionary.class] &&
			[task[@"@type"] isEqualToString:@"inputChecklistTask"]){
			[input addObject:task];
			continue;
		}
		NSString *text = TGFeatureString(task[@"text"]);
		if (!text.length)
			continue;
		[input addObject:@{
			@"@type" : @"inputChecklistTask",
			@"id"    : @([task[@"id"] integerValue]),
			@"text"  : TGFormattedText(text),
		}];
	}
	return @{
		@"@type"                   : @"inputChecklist",
		@"title"                   : TGFormattedText(title ?: @""),
		@"tasks"                   : input,
		@"others_can_add_tasks"    : @(othersCanAdd),
		@"others_can_mark_tasks_as_done": @(othersCanMark),
	};
}


@end
