//
// TGRows.m
//
#import "TGRows.h"
#import "TGChatListStore.h"
#import "TGSendStore.h"
#import "TGStyle.h"
#import "TGMessageLayout.h"

NSString *const TGRowTitle    = @"title";
NSString *const TGRowDetail   = @"detail";
NSString *const TGRowKind     = @"kind";
NSString *const TGRowTap      = @"tap";
NSString *const TGRowToggle   = @"toggle";
NSString *const TGRowOn       = @"on";
NSString *const TGRowChecked  = @"checked";
NSString *const TGRowIcon     = @"icon";
NSString *const TGRowColour   = @"colour";
NSString *const TGRowSubtitle = @"subtitle";
NSString *const TGRowOpens    = @"opens";
NSString *const TGRowBadge    = @"badge";
NSString *const TGRowDestructive = @"destructive";
NSString *const TGRowEnabled  = @"enabled";
NSString *const TGRowDetailLines = @"detailLines";
NSString *const TGRowThemes   = @"themes";
NSString *const TGRowThemeTap = @"themeTap";
NSString *const TGRowCurrentTheme = @"currentTheme";
NSString *const TGRowThemeNames = @"themeNames";
NSString *const TGRowAccessoryTitle = @"accessoryTitle";
NSString *const TGRowAccessoryTap = @"accessoryTap";

NSString *const TGRowPeerId       = @"peerId";
NSString *const TGRowAvatarUser   = @"avatarUser";
NSString *const TGRowAvatarImage  = @"avatarImage";
NSString *const TGRowStatusEmojiId = @"statusEmojiId";
NSString *const TGRowVerified     = @"verified";
NSString *const TGRowOnline       = @"online";
NSString *const TGRowPin          = @"pin";
NSString *const TGRowAccessory    = @"accessory";
NSString *const TGRowBadgeVariant = @"badgeVariant";
NSString *const TGRowBadgeInline  = @"badgeInline";
NSString *const TGRowTitleColour  = @"titleColour";
NSString *const TGRowHeight       = @"height";

NSString *const TGRowAccessoryCheck      = @"check";
NSString *const TGRowAccessoryDisclosure = @"disclosure";
NSString *const TGRowAccessorySwitch     = @"switch";

NSString *const TGKindPlain       = @"plain";
NSString *const TGKindDisclosure  = @"disclosure";
NSString *const TGKindToggle      = @"switch";
NSString *const TGKindCheck       = @"check";
NSString *const TGKindDestructive = @"destructive";
NSString *const TGKindProfile     = @"profile";
NSString *const TGKindPreview     = @"preview";
NSString *const TGKindThemeCards  = @"themecards";
NSString *const TGKindThemeGrid   = @"themegrid";
NSString *const TGKindAction      = @"action";
NSString *const TGKindToggleInfo  = @"switchinfo";
NSString *const TGKindPeerRow     = @"peerrow";

NSDictionary *TGSection(NSString *header, NSString *footer, NSArray *rows) {
	NSMutableDictionary *section = [NSMutableDictionary dictionary];
	if (header) section[@"header"] = header;
	if (footer) section[@"footer"] = footer;
	section[@"rows"] = rows ?: @[];
	return section;
}

NSMutableDictionary *TGRow(NSString *kind, NSString *title) {
	return [@{TGRowKind : kind, TGRowTitle : title ?: @""} mutableCopy];
}

NSDictionary *TGTapRow(NSString *title, NSString *detail, void (^tap)(void)) {
	NSMutableDictionary *row = TGRow(TGKindDisclosure, title);
	if (detail) row[TGRowDetail] = detail;
	if (tap) row[TGRowTap] = [tap copy];
	return row;
}

NSDictionary *TGOpenRow(NSString *title, NSString *detail, void (^tap)(void)) {
	NSMutableDictionary *row = [TGTapRow(title, detail, tap) mutableCopy];
	row[TGRowOpens] = @YES;
	return row;
}

NSDictionary *TGSwitchRow(NSString *title, BOOL on, void (^changed)(BOOL)) {
	NSMutableDictionary *row = TGRow(TGKindToggle, title);
	row[TGRowOn] = @(on);
	if (changed) row[TGRowToggle] = [changed copy];
	return row;
}

NSDictionary *TGSwitchInfoRow(NSString *title, NSString *detail,
		NSString *icon, UIColor *colour, BOOL on, void (^changed)(BOOL)) {
	NSMutableDictionary *row = TGRow(TGKindToggleInfo, title);
	if (detail) row[TGRowDetail] = detail;
	if (icon)   row[TGRowIcon]   = icon;
	if (colour) row[TGRowColour] = colour;
	row[TGRowOn] = @(on);
	if (changed) row[TGRowToggle] = [changed copy];
	return row;
}

NSDictionary *TGCheckRow(NSString *title, NSString *detail,
		BOOL checked, void (^tap)(void)) {
	NSMutableDictionary *row = TGRow(TGKindCheck, title);
	if (detail) row[TGRowDetail] = detail;
	row[TGRowChecked] = @(checked);
	if (tap) row[TGRowTap] = [tap copy];
	return row;
}

NSDictionary *TGSubtitleRow(NSString *title, NSString *subtitle,
		void (^tap)(void)) {
	NSMutableDictionary *row = TGRow(TGKindDisclosure, title);
	if (subtitle) row[TGRowDetail] = subtitle;
	row[TGRowSubtitle] = @YES;
	if (tap) row[TGRowTap] = [tap copy];
	return row;
}

NSDictionary *TGSubtitleOpenRow(NSString *title, NSString *subtitle,
		void (^tap)(void)) {
	NSMutableDictionary *row = [TGSubtitleRow(title, subtitle, tap) mutableCopy];
	row[TGRowOpens] = @YES;
	return row;
}

NSDictionary *TGActionRow(NSString *title, void (^tap)(void)) {
	NSMutableDictionary *row = TGRow(TGKindAction, title);
	if (tap) row[TGRowTap] = [tap copy];
	return row;
}

NSDictionary *TGRedRow(NSString *title, void (^tap)(void)) {
	NSMutableDictionary *row = TGRow(TGKindDestructive, title);
	if (tap) row[TGRowTap] = [tap copy];
	return row;
}

NSDictionary *TGIconRow(NSString *title, NSString *icon, UIColor *colour,
		void (^tap)(void)) {
	NSMutableDictionary *row = TGRow(TGKindDisclosure, title);
	row[TGRowIcon] = icon;
	row[TGRowColour] = colour;
	if (tap) row[TGRowTap] = [tap copy];
	return row;
}

NSDictionary *TGIconOpenRow(NSString *title, NSString *icon, UIColor *colour,
		void (^tap)(void)) {
	NSMutableDictionary *row = [TGIconRow(title, icon, colour, tap) mutableCopy];
	row[TGRowOpens] = @YES;
	return row;
}

NSDictionary *TGIconTapRow(NSString *title, NSString *detail,
		NSString *icon, UIColor *colour, void (^tap)(void)) {
	NSMutableDictionary *row = [TGIconRow(title, icon, colour, tap) mutableCopy];
	if (detail) row[TGRowDetail] = detail;
	return row;
}

NSDictionary *TGIconTapOpenRow(NSString *title, NSString *detail,
		NSString *icon, UIColor *colour, void (^tap)(void)) {
	NSMutableDictionary *row = [TGIconTapRow(title, detail, icon, colour, tap)
			mutableCopy];
	row[TGRowOpens] = @YES;
	return row;
}

NSMutableDictionary *TGPeerRow(NSNumber *peerId, NSString *title,
		NSString *subtitle, void (^tap)(void)) {
	NSMutableDictionary *row = TGRow(TGKindPeerRow, title);
	if (peerId) row[TGRowPeerId] = peerId;
	if (subtitle) row[TGRowDetail] = subtitle;
	if (tap) row[TGRowTap] = [tap copy];
	return row;
}

BOOL TGPeerRowIsChecked(NSDictionary *row) {
	return [row[TGRowChecked] boolValue];
}

UIColor *TGPeerRowSubtitleColour(BOOL online, UIColor *accent,
		UIColor *secondary) {
	return online ? (accent ?: secondary) : secondary;
}

NSDictionary *TGButtonRow(NSString *title, NSString *detail,
		NSString *buttonTitle, void (^buttonTap)(void), void (^tap)(void)) {
	NSMutableDictionary *row = [TGSubtitleRow(title, detail, tap) mutableCopy];
	if (buttonTitle) row[TGRowAccessoryTitle] = buttonTitle;
	if (buttonTap) row[TGRowAccessoryTap] = [buttonTap copy];
	return row;
}

BOOL TGRowsSectionIconsConsistent(NSArray *rows) {
	if (!rows.count)
		return YES;
	BOOL firstHasIcon = [rows[0][TGRowIcon] length] > 0;
	for (NSUInteger i = 1; i < rows.count; i++){
		BOOL hasIcon = [rows[i][TGRowIcon] length] > 0;
		if (hasIcon != firstHasIcon)
			return NO;
	}
	return YES;
}

#pragma mark - row text and accessory

NSString *const TGRowTitleLines = @"titleLines";
NSString *const TGRowAccessoryColour = @"accessoryColour";

#pragma mark - row detail, flags and preview

NSString *const TGRowDetailColour = @"detailColour";
NSString *const TGRowCentred = @"centred";
NSString *const TGRowRawTitle = @"rawTitle";
NSString *const TGRowRawDetail = @"rawDetail";
NSString *const TGRowAccessoryImage = @"accessoryImage";

NSString *const TGKindAppearancePreview = @"appearancepreview";
NSString *const TGKindSwatchStrip = @"swatchstrip";
NSString *const TGRowPreviewImage = @"previewImage";
NSString *const TGRowPreviewText = @"previewText";
NSString *const TGRowPreviewTextColour = @"previewTextColour";
NSString *const TGRowSwatches = @"swatches";
NSString *const TGRowSwatchTap = @"swatchTap";

NSDictionary *TGCentredDestructiveRow(NSString *title, void (^tap)(void)) {
	NSMutableDictionary *row = [TGRedRow(title, tap) mutableCopy];
	row[TGRowCentred] = @YES;
	return row;
}

CGFloat TGRowsToggleInfoHeight(CGFloat titleHeight, CGFloat detailHeight) {
	CGFloat text = TGMetricPad + ceilf(titleHeight) + TGMetricPadTiny +
			ceilf(detailHeight) + TGMetricPad;
	return MAX(TGMetricActionTile, text);
}

#pragma mark - grid rows

NSString *const TGKindGrid       = @"grid";
NSString *const TGRowGridItems   = @"gridItems";
NSString *const TGRowGridColumns = @"gridColumns";
NSString *const TGRowGridTap     = @"gridTap";

NSString *const TGGridItemImage    = @"image";
NSString *const TGGridItemInitials = @"initials";
NSString *const TGGridItemEmoji    = @"emoji";
NSString *const TGGridItemColour   = @"colour";
NSString *const TGGridItemCaption  = @"caption";
NSString *const TGGridItemChecked  = @"checked";
NSString *const TGGridItemLocked   = @"locked";
NSString *const TGGridItemBadge    = @"badge";
NSString *const TGGridItemEnabled  = @"enabled";
NSString *const TGGridItemTap      = @"tileTap";
NSString *const TGGridItemHold     = @"tileHold";

NSMutableDictionary *TGGridRow(NSArray *items, NSInteger columns,
		void (^tap)(NSInteger index)) {
	NSMutableDictionary *row = TGRow(TGKindGrid, @"");
	row[TGRowGridItems] = [items copy] ?: @[];
	row[TGRowGridColumns] = @(MAX((NSInteger)1, columns));
	if (tap)
		row[TGRowGridTap] = [tap copy];
	return row;
}

#pragma mark - field and form rows

NSString *const TGRowFieldText        = @"fieldText";
NSString *const TGRowFieldPlaceholder = @"fieldPlaceholder";
NSString *const TGRowFieldChanged     = @"fieldChanged";
NSString *const TGRowFieldEndEditing  = @"fieldEndEditing";
NSString *const TGRowFieldIdentifier  = @"fieldIdentifier";
NSString *const TGRowFieldKeyboard    = @"fieldKeyboard";
NSString *const TGRowFieldSecure      = @"fieldSecure";
NSString *const TGRowFieldMaxLength   = @"fieldMaxLength";
NSString *const TGRowFieldPrefix      = @"fieldPrefix";
NSString *const TGRowFieldClear       = @"fieldClear";
NSString *const TGRowFieldReturn      = @"fieldReturn";
NSString *const TGRowFieldReturnKey   = @"fieldReturnKey";
NSString *const TGRowFieldAutocapitalization = @"fieldAutocapitalization";
NSString *const TGRowFieldAutocorrection     = @"fieldAutocorrection";
NSString *const TGRowTextTone         = @"textTone";
NSString *const TGRowImage            = @"image";
NSString *const TGRowImageLoader      = @"imageLoader";
NSString *const TGRowCanMove          = @"canMove";
NSString *const TGRowMove             = @"move";

NSString *const TGKindField          = @"field";
NSString *const TGKindMultilineField = @"multilinefield";
NSString *const TGKindNote           = @"note";
NSString *const TGKindPhoto          = @"photo";
NSString *const TGKindImageCheck     = @"imagecheck";

NSMutableDictionary *TGFieldRow(NSString *placeholder, NSString *text,
		void (^changed)(NSString *text)) {
	NSMutableDictionary *row = TGRow(TGKindField, @"");
	row[TGRowFieldPlaceholder] = placeholder ?: @"";
	row[TGRowFieldText] = [text isKindOfClass:NSString.class] ? text : @"";
	if (changed)
		row[TGRowFieldChanged] = [changed copy];
	return row;
}

NSMutableDictionary *TGMultilineFieldRow(NSString *placeholder, NSString *text,
		void (^changed)(NSString *text)) {
	NSMutableDictionary *row = TGRow(TGKindMultilineField, @"");
	row[TGRowFieldPlaceholder] = placeholder ?: @"";
	row[TGRowFieldText] = [text isKindOfClass:NSString.class] ? text : @"";
	if (changed)
		row[TGRowFieldChanged] = [changed copy];
	return row;
}

NSString *TGRowFieldKey(NSDictionary *row) {
	NSString *identifier = row[TGRowFieldIdentifier];
	if ([identifier isKindOfClass:NSString.class] && identifier.length)
		return identifier;
	NSString *placeholder = row[TGRowFieldPlaceholder];
	return [placeholder isKindOfClass:NSString.class] ? placeholder : nil;
}

BOOL TGFieldTextWithinLimit(NSString *text, NSInteger maxLength) {
	if (maxLength <= 0)
		return YES;
	NSString *value = [text isKindOfClass:NSString.class] ? text : @"";
	return (NSInteger)value.length <= maxLength;
}

NSString *TGFieldCounterText(NSString *text, NSInteger maxLength, BOOL *exceeded) {
	if (exceeded)
		*exceeded = NO;
	if (maxLength <= 0)
		return nil;
	NSString *value = [text isKindOfClass:NSString.class] ? text : @"";
	NSInteger length = (NSInteger)value.length;
	// Official shows the counter only once the text passes 70% of the limit.
	if (length <= maxLength * 70 / 100)
		return nil;
	NSInteger remaining = maxLength - length;
	if (exceeded)
		*exceeded = remaining < 0;
	return [NSString stringWithFormat:@"%ld", (long)remaining];
}

static BOOL TGRowIsInput(NSDictionary *row) {
	NSString *kind = row[TGRowKind];
	return [kind isEqualToString:TGKindField] ||
			[kind isEqualToString:TGKindMultilineField];
}

NSDictionary *TGRowsFieldTexts(NSArray *sections) {
	NSMutableDictionary *texts = [NSMutableDictionary dictionary];
	for (NSDictionary *section in sections){
		if (![section isKindOfClass:NSDictionary.class])
			continue;
		for (NSDictionary *row in section[@"rows"]){
			if (![row isKindOfClass:NSDictionary.class] || !TGRowIsInput(row))
				continue;
			NSString *key = TGRowFieldKey(row);
			if (!key.length)
				continue;
			NSString *text = row[TGRowFieldText];
			texts[key] = [text isKindOfClass:NSString.class] ? text : @"";
		}
	}
	return texts;
}

NSArray *TGRowsApplyingFieldTexts(NSArray *sections, NSDictionary *texts) {
	if (!texts.count || ![sections isKindOfClass:NSArray.class])
		return sections;
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:sections.count];
	for (NSDictionary *section in sections){
		if (![section isKindOfClass:NSDictionary.class]){
			[result addObject:section];
			continue;
		}
		NSArray *rows = section[@"rows"];
		if (![rows isKindOfClass:NSArray.class]){
			[result addObject:section];
			continue;
		}
		NSMutableArray *newRows = [NSMutableArray arrayWithCapacity:rows.count];
		for (NSDictionary *row in rows){
			NSString *key = [row isKindOfClass:NSDictionary.class]
					? TGRowFieldKey(row) : nil;
			NSString *remembered = key.length ? texts[key] : nil;
			if (TGRowIsInput(row) && [remembered isKindOfClass:NSString.class]){
				NSMutableDictionary *updated = [row mutableCopy];
				updated[TGRowFieldText] = remembered;
				[newRows addObject:updated];
			} else {
				[newRows addObject:row];
			}
		}
		NSMutableDictionary *newSection = [section mutableCopy];
		newSection[@"rows"] = newRows;
		[result addObject:newSection];
	}
	return result;
}

#pragma mark - labelled value

NSString *const TGRowLabelAbove = @"labelAbove";
NSString *const TGRowDetailAccent = @"detailAccent";

#pragma mark - call screen rows

NSString *const TGRowTrailingImage = @"trailingImage";

#pragma mark - settings and profile elements

NSString *const TGKindProfileHeader = @"profileheader";
NSString *const TGKindChatPreview = @"chatpreview";

NSMutableDictionary *TGProfileHeaderRow(NSNumber *userId, NSString *name,
		NSString *detail, UIImage *avatar, void (^avatarLoader)(UIImageView *),
		void (^tap)(void)) {
	NSMutableDictionary *row = TGRow(TGKindProfileHeader, name ?: @"");
	if (userId)
		row[TGRowPeerId] = userId;
	if (detail)
		row[TGRowDetail] = detail;
	if (avatar)
		row[TGRowImage] = avatar;
	if (avatarLoader)
		row[TGRowImageLoader] = [avatarLoader copy];
	if (tap)
		row[TGRowTap] = [tap copy];
	return row;
}

NSMutableDictionary *TGChatPreviewRow(void) {
	return TGRow(TGKindChatPreview, @"");
}

NSMutableDictionary *TGThemeCardsRow(NSArray *themes, NSString *currentThemeId,
		BOOL showsNames, void (^tap)(NSString *themeId)) {
	NSMutableDictionary *row = TGRow(TGKindThemeCards, @"");
	row[TGRowThemes] = [themes copy] ?: @[];
	if (currentThemeId)
		row[TGRowCurrentTheme] = [currentThemeId copy];
	if (showsNames)
		row[TGRowThemeNames] = @YES;
	if (tap)
		row[TGRowThemeTap] = [tap copy];
	return row;
}

NSMutableDictionary *TGThemeGridRow(NSArray *themes, NSString *currentThemeId,
		void (^tap)(NSString *themeId)) {
	NSMutableDictionary *row = TGRow(TGKindThemeGrid, @"");
	row[TGRowThemes] = [themes copy] ?: @[];
	if (currentThemeId)
		row[TGRowCurrentTheme] = [currentThemeId copy];
	if (tap)
		row[TGRowThemeTap] = [tap copy];
	return row;
}

#pragma mark - message results and contact index

NSString *const TGKindMessageResult = @"messageresult";
NSString *const TGRowMessageText = @"messageText";
NSString *const TGRowMessageDate = @"messageDate";

NSMutableDictionary *TGMessageResultRow(NSNumber *chatId, NSString *title,
		NSString *text, NSString *date, void (^tap)(void)) {
	NSMutableDictionary *row = TGRow(TGKindMessageResult, title ?: @"");
	if (chatId)
		row[TGRowPeerId] = chatId;
	if (text)
		row[TGRowMessageText] = text;
	if (date.length)
		row[TGRowMessageDate] = date;
	if (tap)
		row[TGRowTap] = [tap copy];
	return row;
}

NSDictionary *TGRowFromListEntry(NSDictionary *entry) {
	if (![entry isKindOfClass:NSDictionary.class])
		return TGRow(TGKindPlain, @"");
	NSString *title = entry[TGRowTitle] ?: @"";
	void (^tap)(void) = entry[TGRowTap];
	BOOL destructive = [entry[TGRowDestructive] boolValue];
	NSMutableDictionary *row = destructive
			? [TGRedRow(title, tap) mutableCopy]
			: [TGTapRow(title, entry[TGRowDetail], tap) mutableCopy];
	if (destructive && entry[TGRowDetail])
		row[TGRowDetail] = entry[TGRowDetail];
	if ([entry[TGRowOpens] boolValue])
		row[TGRowOpens] = @YES;
	return row;
}

NSArray *TGRowsFromListEntries(NSArray *entries) {
	if (![entries isKindOfClass:NSArray.class] || !entries.count)
		return @[];
	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:entries.count];
	for (NSDictionary *entry in entries)
		[rows addObject:TGRowFromListEntry(entry)];
	return rows;
}

NSString *TGContactSectionTitle(NSString *name) {
	NSString *trimmed = [name stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!trimmed.length)
		return @"#";
	NSRange r = [trimmed rangeOfComposedCharacterSequenceAtIndex:0];
	if (r.length != 1)
		return @"#";
	NSString *first = [[trimmed substringWithRange:r] uppercaseString];
	unichar c = [first characterAtIndex:0];
	if ((c >= 'A' && c <= 'Z') || (c >= 0x0400 && c <= 0x04FF))
		return first;
	return @"#";
}

#pragma mark - profile media: picture rows and the tab strip

NSString *const TGKindPicture = @"picture";
NSString *const TGRowPictureImage = @"pictureImage";
NSString *const TGRowPictureGlyph = @"pictureGlyph";
NSString *const TGRowPictureGlyphColour = @"pictureGlyphColour";
NSString *const TGRowPicturePlaceholder = @"picturePlaceholder";

NSMutableDictionary *TGPictureRow(NSString *title, NSString *subtitle,
		void (^tap)(void)) {
	NSMutableDictionary *row = TGRow(TGKindPicture, title);
	row[TGRowSubtitle] = @YES;
	if (subtitle)
		row[TGRowDetail] = subtitle;
	if (tap)
		row[TGRowTap] = [tap copy];
	return row;
}

NSString *const TGKindTabStrip = @"tabstrip";
NSString *const TGRowTabStripItems = @"tabStripItems";
NSString *const TGRowTabStripSelected = @"tabStripSelected";
NSString *const TGRowTabStripTap = @"tabStripTap";
NSString *const TGRowTabStripHold = @"tabStripHold";
NSString *const TGRowTabStripOffset = @"tabStripOffset";
NSString *const TGRowTabStripOffsetChanged = @"tabStripOffsetChanged";
NSString *const TGRowTabStripAccentColour = @"tabStripAccentColour";
NSString *const TGRowTabStripSecondaryColour = @"tabStripSecondaryColour";
NSString *const TGRowTabStripBackgroundColour = @"tabStripBackgroundColour";

NSMutableDictionary *TGTabStripRow(NSArray *tabs, NSString *selected,
		void (^tap)(NSString *kind)) {
	NSMutableDictionary *row = TGRow(TGKindTabStrip, @"");
	row[TGRowTabStripItems] = [tabs copy] ?: @[];
	if (selected)
		row[TGRowTabStripSelected] = selected;
	if (tap)
		row[TGRowTabStripTap] = [tap copy];
	return row;
}

#pragma mark - chat list rows

NSString *const TGKindChatRow     = @"chatrow";
NSString *const TGKindStoryStrip  = @"storystrip";

NSString *const TGRowChatId            = @"chatId";
NSString *const TGRowChatPreview       = @"chatPreview";
NSString *const TGRowChatAuthor        = @"chatAuthor";
NSString *const TGRowChatDate          = @"chatDate";
NSString *const TGRowChatCustomEmoji   = @"chatCustomEmoji";
NSString *const TGRowChatUnread        = @"chatUnread";
NSString *const TGRowChatMentions      = @"chatMentions";
NSString *const TGRowChatMarkedUnread  = @"chatMarkedUnread";
NSString *const TGRowChatMuted         = @"chatMuted";
NSString *const TGRowChatPinned        = @"chatPinned";
NSString *const TGRowChatOnline        = @"chatOnline";
NSString *const TGRowChatSaved         = @"chatSaved";
NSString *const TGRowChatOutgoing      = @"chatOutgoing";
NSString *const TGRowChatRead          = @"chatRead";
NSString *const TGRowChatFailed        = @"chatFailed";
NSString *const TGRowChatAction        = @"chatAction";
NSString *const TGRowChatDraft         = @"chatDraft";
NSString *const TGRowChatStatusEmojiId = @"chatStatusEmojiId";
NSString *const TGRowChatAvatarId      = @"chatAvatarId";
NSString *const TGRowChatAvatarImage   = @"chatAvatarImage";
NSString *const TGRowChatAvatarGlyph   = @"chatAvatarGlyph";
NSString *const TGRowChatPreviewKind   = @"chatPreviewKind";
NSString *const TGRowChatPreviewFileId = @"chatPreviewFileId";
NSString *const TGRowChatPreviewImage  = @"chatPreviewImage";
NSString *const TGRowChatPreviewBadge  = @"chatPreviewBadge";
NSString *const TGRowChatLayout        = @"chatLayout";

NSString *const TGChatAvatarGlyphArchive = @"archive";
NSString *const TGChatAvatarGlyphSaved   = @"saved";

static NSNumber *TGChatRowNumber(id value) {
	return [value isKindOfClass:NSNumber.class] ? value : @0;
}

static NSString *TGChatRowString(id value) {
	return [value isKindOfClass:NSString.class] ? value : nil;
}

/// M24: a scalar Apple Color Emoji cannot draw costs seconds on a 4S when a
/// row lays it out. Strip it before the row model, not after.
static NSString *TGChatRowClean(NSString *text) {
	return text.length ? TGStripUndrawableScalars(text) : @"";
}

/// Only the fields a row draws cross over. The chat dictionary also carries
/// TDLib records (permissions, action bar, background) that are not row data.
NSMutableDictionary *TGChatRow(NSDictionary *chat, NSString *dateText) {
	if (![chat isKindOfClass:NSDictionary.class])
		chat = @{};
	NSMutableDictionary *row = TGRow(TGKindChatRow,
			TGChatRowClean(TGChatRowString(chat[@"title"]) ?: @""));
	NSNumber *chatId = TGChatRowNumber(chat[@"id"]);
	row[TGRowChatId] = chatId;
	row[TGRowChatAvatarId] = chatId;

	NSString *rawPreview = TGChatRowString(chat[@"previewText"]);
	if (!rawPreview)
		rawPreview = TGChatRowString(chat[@"text"]);
	NSString *preview = TGChatRowClean(rawPreview ?: @"");
	row[TGRowChatPreview] = preview;
	NSString *author = TGChatRowString(chat[@"lastAuthor"]);
	if (author.length)
		row[TGRowChatAuthor] = TGChatRowClean(author);
	if ([dateText isKindOfClass:NSString.class])
		row[TGRowChatDate] = dateText;
	// The ranges count the original string; stripping can move them.
	NSArray *emoji = chat[@"previewCustomEmoji"];
	if ([emoji isKindOfClass:NSArray.class] && emoji.count &&
			[preview isEqualToString:rawPreview ?: @""])
		row[TGRowChatCustomEmoji] = emoji;

	row[TGRowChatUnread] = TGChatRowNumber(chat[@"unread"]);
	row[TGRowChatMentions] = TGChatRowNumber(chat[@"unreadMentions"]);
	row[TGRowChatMarkedUnread] = @([chat[@"markedUnread"] boolValue]);
	row[TGRowChatMuted] = @([chat[@"isMuted"] boolValue]);
	row[TGRowChatPinned] = @([chat[@"isPinned"] boolValue]);
	row[TGRowChatOnline] = @([chat[@"isOnline"] boolValue]);
	row[TGRowChatSaved] = @([chat[@"isSaved"] boolValue]);
	row[TGRowChatOutgoing] = @([chat[@"lastOutgoing"] boolValue]);
	row[TGRowChatRead] = @([chat[@"lastId"] longLongValue] <=
			[chat[@"readOutbox"] longLongValue]);
	// The last bubble was refused: the row shows the same mark as the chat.
	int64_t lastId = [chat[@"lastId"] longLongValue];
	row[TGRowChatFailed] = @(lastId > 0 &&
			[[TGSendStore shared] stateForMessageId:lastId
											 inChat:[chatId longLongValue]] ==
					TGSendStateFailed);
	if ([TGChatRowString(chat[@"action"]) length])
		row[TGRowChatAction] = TGChatRowClean(chat[@"action"]);
	if ([TGChatRowString(chat[@"draft"]) length])
		row[TGRowChatDraft] = TGChatRowClean(chat[@"draft"]);
	if ([chat[@"emojiStatusId"] isKindOfClass:NSNumber.class])
		row[TGRowChatStatusEmojiId] = chat[@"emojiStatusId"];

	// M24: the media kind, its thumbnail and the compact trailing facts.
	TGChatListStore *list = [TGChatListStore shared];
	NSString *kind = [list previewKindForChat:chat];
	if (kind.length)
		row[TGRowChatPreviewKind] = kind;
	NSNumber *previewFileId = [list previewFileIdForChat:chat];
	if (previewFileId){
		row[TGRowChatPreviewFileId] = previewFileId;
		UIImage *image = [list cachedPreviewImageForFileId:previewFileId];
		if (image)
			row[TGRowChatPreviewImage] = image;
	}
	NSString *previewBadge = [list trailingBadgeForChat:chat];
	if (previewBadge.length)
		row[TGRowChatPreviewBadge] = previewBadge;
	return row;
}

NSMutableDictionary *TGArchiveChatRow(NSString *title, NSString *subtitle) {
	NSMutableDictionary *row = TGRow(TGKindChatRow, title ?: @"");
	row[TGRowChatPreview] = subtitle ?: @"";
	row[TGRowChatAvatarGlyph] = TGChatAvatarGlyphArchive;
	row[TGRowChatUnread] = @0;
	row[TGRowChatMentions] = @0;
	return row;
}

NSMutableDictionary *TGSavedMessagesChatRow(NSString *title, NSString *subtitle) {
	NSMutableDictionary *row = TGRow(TGKindChatRow, title ?: @"");
	row[TGRowChatPreview] = subtitle ?: @"";
	row[TGRowChatAvatarGlyph] = TGChatAvatarGlyphSaved;
	row[TGRowChatSaved] = @YES;
	row[TGRowChatUnread] = @0;
	row[TGRowChatMentions] = @0;
	return row;
}

NSString *const TGRowStories       = @"stories";
NSString *const TGRowOwnStory      = @"ownStory";
NSString *const TGRowStoryAdd      = @"storyAdd";
NSString *const TGRowStoryMore     = @"storyMore";
NSString *const TGRowStoryMyTap    = @"storyMyTap";
NSString *const TGRowStoryMyHold   = @"storyMyHold";
NSString *const TGRowStoryTap      = @"storyTap";
NSString *const TGRowStoryHold     = @"storyHold";

NSMutableDictionary *TGStoryStripRow(NSArray *stories, NSDictionary *ownStory) {
	NSMutableDictionary *row = TGRow(TGKindStoryStrip, @"");
	row[TGRowStories] = [stories isKindOfClass:NSArray.class]
			? [stories copy] : @[];
	if ([ownStory isKindOfClass:NSDictionary.class])
		row[TGRowOwnStory] = [ownStory copy];
	return row;
}
