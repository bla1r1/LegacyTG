//
// TGRows.h - the one row model: sections of dictionary rows.
//
// Settings grew this model first; the Tier 2 lists and the screens built from
// rows use the same keys, kinds and builders so a row is described once and
// rendered by one cell family.
//
#ifndef TGROWS_H
#define TGROWS_H

#import <UIKit/UIKit.h>

@class UIImageView;

#ifdef __cplusplus
extern "C" {
#endif

#pragma mark - keys

extern NSString *const TGRowTitle;
extern NSString *const TGRowDetail;
extern NSString *const TGRowKind;
extern NSString *const TGRowTap;       // void(^)(void)
extern NSString *const TGRowToggle;    // void(^)(BOOL)
extern NSString *const TGRowOn;
extern NSString *const TGRowChecked;
extern NSString *const TGRowIcon;
extern NSString *const TGRowColour;
extern NSString *const TGRowSubtitle;
extern NSString *const TGRowOpens;
extern NSString *const TGRowBadge;     // red warning mark, or a peer row's badge
extern NSString *const TGRowDestructive; // TGFeature compatibility
extern NSString *const TGRowThemes;    // NSArray of theme entries
extern NSString *const TGRowThemeTap;  // void(^)(NSString *themeId)
extern NSString *const TGRowCurrentTheme;
extern NSString *const TGRowThemeNames; // names under the cards
extern NSString *const TGRowEnabled;   // switch rows: NO renders it disabled
extern NSString *const TGRowDetailLines; // > 1 wraps the detail text
extern NSString *const TGRowAccessoryTitle; // button beside the row
extern NSString *const TGRowAccessoryTap;   // void(^)(void)

#pragma mark - peer row keys

extern NSString *const TGRowPeerId;      // NSNumber, user or chat id
extern NSString *const TGRowAvatarUser;  // NSNumber BOOL, load through the member avatar store
extern NSString *const TGRowAvatarImage; // UIImage already decoded by the screen
extern NSString *const TGRowStatusEmojiId; // NSNumber, emoji status beside the name
extern NSString *const TGRowVerified;    // NSNumber BOOL, verified mark after the name
extern NSString *const TGRowOnline;      // NSNumber BOOL, subtitle in the accent colour
extern NSString *const TGRowPin;         // NSNumber BOOL, pin before the title
extern NSString *const TGRowAccessory;   // one of TGRowAccessory* below, or trailing text
extern NSString *const TGRowBadgeVariant; // NSNumber TGBadgeVariant
extern NSString *const TGRowBadgeInline;  // NSNumber BOOL, badge after the name
extern NSString *const TGRowTitleColour;  // UIColor for the name
extern NSString *const TGRowHeight;       // NSNumber, row height from TGStyle

extern NSString *const TGRowAccessoryCheck;
extern NSString *const TGRowAccessoryDisclosure;
extern NSString *const TGRowAccessorySwitch;

#pragma mark - kinds

extern NSString *const TGKindPlain;
extern NSString *const TGKindDisclosure;
extern NSString *const TGKindToggle;
extern NSString *const TGKindCheck;
extern NSString *const TGKindDestructive;
extern NSString *const TGKindProfile;
extern NSString *const TGKindPreview;    // the sample chat
extern NSString *const TGKindThemeCards; // horizontal theme carousel
extern NSString *const TGKindThemeGrid;  // 3-column theme grid
extern NSString *const TGKindAction;     // blue text, no chevron
extern NSString *const TGKindToggleInfo; // icon, description, switch
extern NSString *const TGKindPeerRow;    // avatar, name, subtitle, one accessory

/// A section is "header", "footer" and "rows".
NSDictionary *TGSection(NSString *header, NSString *footer, NSArray *rows);

NSMutableDictionary *TGRow(NSString *kind, NSString *title);
NSDictionary *TGTapRow(NSString *title, NSString *detail, void (^tap)(void));
NSDictionary *TGOpenRow(NSString *title, NSString *detail, void (^tap)(void));
NSDictionary *TGSwitchRow(NSString *title, BOOL on, void (^changed)(BOOL));
NSDictionary *TGSwitchInfoRow(NSString *title, NSString *detail,
		NSString *icon, UIColor *colour, BOOL on, void (^changed)(BOOL));
NSDictionary *TGCheckRow(NSString *title, NSString *detail,
		BOOL checked, void (^tap)(void));
NSDictionary *TGSubtitleRow(NSString *title, NSString *subtitle, void (^tap)(void));
NSDictionary *TGSubtitleOpenRow(NSString *title, NSString *subtitle,
		void (^tap)(void));
NSDictionary *TGActionRow(NSString *title, void (^tap)(void));
NSDictionary *TGRedRow(NSString *title, void (^tap)(void));
NSDictionary *TGIconRow(NSString *title, NSString *icon, UIColor *colour,
		void (^tap)(void));
NSDictionary *TGIconOpenRow(NSString *title, NSString *icon, UIColor *colour,
		void (^tap)(void));
NSDictionary *TGIconTapRow(NSString *title, NSString *detail,
		NSString *icon, UIColor *colour, void (^tap)(void));
NSDictionary *TGIconTapOpenRow(NSString *title, NSString *detail,
		NSString *icon, UIColor *colour, void (^tap)(void));
NSDictionary *TGButtonRow(NSString *title, NSString *detail,
		NSString *buttonTitle, void (^buttonTap)(void), void (^tap)(void));

/// One person or chat row. `peerId` drives the initials avatar and, when
/// `TGRowAvatarUser` is set, the picture lookup. The row carries its own tap:
/// screens never reach into a cell to find out what it draws.
NSMutableDictionary *TGPeerRow(NSNumber *peerId, NSString *title,
		NSString *subtitle, void (^tap)(void));

/// YES when the row's check accessory is ticked.
BOOL TGPeerRowIsChecked(NSDictionary *row);

/// A peer row's subtitle is the accent colour while the person is online and
/// the secondary colour otherwise. Pure so the rule can be tested without a
/// theme or a cell.
UIColor *TGPeerRowSubtitleColour(BOOL online, UIColor *accent,
		UIColor *secondary);

/// YES when every row in the section carries an icon, or none does. A section
/// is the visual unit: one icon in a list of plain rows leaves the text
/// columns ragged, which is the bug this rule exists to stop.
BOOL TGRowsSectionIconsConsistent(NSArray *rows);

#pragma mark - row text and accessory

/// NSNumber line count for the title. 0 means no limit, 1 is the normal single
/// line; the cell grows to fit when it is anything other than 1.
extern NSString *const TGRowTitleLines;

/// UIColor for a string TGRowAccessory shown at the trailing edge of a normal
/// row. Peer rows colour their badge by variant instead.
extern NSString *const TGRowAccessoryColour;

#pragma mark - row detail, flags and preview

/// A colour role for the value on the right: the capability screen's green
/// "On", a profile card's warning red. The cell's own configure sets the
/// default; a screen overrides it with -applyAppendedOptions:.
extern NSString *const TGRowDetailColour;
/// YES centres the title and drops the value and accessory: the Log out row
/// on This Device, the Reset row on Your Color.
extern NSString *const TGRowCentred;
/// YES keeps the title exactly as the screen set it. An account's bio, a
/// username or a group's description is not a pack key and must not be run
/// through TGLocalized.
extern NSString *const TGRowRawTitle;
/// The same for the value.
extern NSString *const TGRowRawDetail;
/// UIImage for a button accessory (the profile card's QR glyph). TGRowAccessoryTap
/// is its block.
extern NSString *const TGRowAccessoryImage;

/// Your Color's live preview row and its strip of colour swatches.
extern NSString *const TGKindAppearancePreview;
extern NSString *const TGKindSwatchStrip;
extern NSString *const TGRowPreviewImage;      // UIImage
extern NSString *const TGRowPreviewText;       // NSString, the account name
extern NSString *const TGRowPreviewTextColour; // UIColor for the account name
extern NSString *const TGRowSwatches;          // NSArray of UIImage
extern NSString *const TGRowSwatchTap;         // void(^)(NSInteger)

/// The centred red row: Log out, Reset, a destructive action on its own.
NSDictionary *TGCentredDestructiveRow(NSString *title, void (^tap)(void));

/// The height of an icon + title + two-line detail + switch row, from the
/// measured heights of its two labels. Pure, so the Power Saving rows can be
/// checked without a table or a font.
CGFloat TGRowsToggleInfoHeight(CGFloat titleHeight, CGFloat detailHeight);


#pragma mark - grid rows

/// The grid kind, appended here so the existing kinds above are untouched.
extern NSString *const TGKindGrid;

/// A grid row carries one line of square tiles. Columns is the line's count;
/// the screen chunks its list into rows so a row never wraps.
extern NSString *const TGRowGridItems;   // NSArray of tile dictionaries
extern NSString *const TGRowGridColumns; // NSNumber
extern NSString *const TGRowGridTap;     // void(^)(NSInteger index) for the line

/// One tile. A picture is drawn when "image" is set; until then the tile is
/// the placeholder colour with its initials (or emoji) in the middle.
extern NSString *const TGGridItemImage;
extern NSString *const TGGridItemInitials;
extern NSString *const TGGridItemEmoji;
extern NSString *const TGGridItemColour;   // UIColor placeholder fill
extern NSString *const TGGridItemCaption;  // optional line under the square
extern NSString *const TGGridItemChecked;  // NSNumber BOOL, check mark
extern NSString *const TGGridItemLocked;   // NSNumber BOOL, lock over the tile
extern NSString *const TGGridItemBadge;    // NSString or NSNumber, red badge
extern NSString *const TGGridItemEnabled;  // NSNumber BOOL, NO dims the tile
extern NSString *const TGGridItemTap;      // void(^)(void), overrides the row
extern NSString *const TGGridItemHold;     // void(^)(void), long press

/// One line of tiles. Tapping a tile calls `tap` with its index unless the tile
/// carries its own TGGridItemTap. Hold is per tile via TGGridItemHold.
NSMutableDictionary *TGGridRow(NSArray *items, NSInteger columns,
		void (^tap)(NSInteger index));


#pragma mark - field and form rows

extern NSString *const TGRowFieldText;        // NSString, the value in the field
extern NSString *const TGRowFieldPlaceholder; // NSString
extern NSString *const TGRowFieldChanged;     // void(^)(NSString *text)
extern NSString *const TGRowFieldEndEditing;  // void(^)(NSString *text)
extern NSString *const TGRowFieldIdentifier;  // stable key for text preservation
extern NSString *const TGRowFieldKeyboard;    // NSNumber UIKeyboardType
extern NSString *const TGRowFieldSecure;      // NSNumber BOOL
extern NSString *const TGRowFieldMaxLength;   // NSNumber, 0 or absent is unlimited
extern NSString *const TGRowFieldPrefix;      // NSString, e.g. "t.me/"
extern NSString *const TGRowFieldClear;       // NSNumber BOOL, the clear button
extern NSString *const TGRowFieldReturn;      // void(^)(void), return key
extern NSString *const TGRowFieldReturnKey;   // NSNumber UIReturnKeyType
extern NSString *const TGRowFieldAutocapitalization; // NSNumber
extern NSString *const TGRowFieldAutocorrection;     // NSNumber
extern NSString *const TGRowTextTone;         // NSNumber 0 secondary, 1 accent, 2 destructive
extern NSString *const TGRowImage;            // UIImage
extern NSString *const TGRowImageLoader;      // void(^)(UIImageView *)
extern NSString *const TGRowCanMove;          // NSNumber BOOL, table reordering
extern NSString *const TGRowMove;             // void(^)(NSInteger from, NSInteger to)

extern NSString *const TGKindField;
extern NSString *const TGKindMultilineField;
extern NSString *const TGKindNote;
extern NSString *const TGKindPhoto;
extern NSString *const TGKindImageCheck;

/// A one-line field. `changed` runs on every edit, as official's textUpdated.
NSMutableDictionary *TGFieldRow(NSString *placeholder, NSString *text,
		void (^changed)(NSString *text));
/// A growing field with the official character counter in its corner.
NSMutableDictionary *TGMultilineFieldRow(NSString *placeholder, NSString *text,
		void (^changed)(NSString *text));

/// The key a field row is remembered by: its identifier, else its placeholder.
NSString *TGRowFieldKey(NSDictionary *row);

/// The official limit rule: 0 is unlimited; otherwise the typed text may not
/// pass the limit.
BOOL TGFieldTextWithinLimit(NSString *text, NSInteger maxLength);

/// The official counter: hidden until more than 70% of the limit is used, then
/// the remaining characters; past the limit the number is negative.
NSString *TGFieldCounterText(NSString *text, NSInteger maxLength, BOOL *exceeded);

/// Every field's text keyed by TGRowFieldKey, for a reload that has to keep it.
NSDictionary *TGRowsFieldTexts(NSArray *sections);

/// The same sections with remembered field text put back. Other rows are
/// untouched and the input sections are not mutated.
NSArray *TGRowsApplyingFieldTexts(NSArray *sections, NSDictionary *texts);


#pragma mark - labelled value

/// YES draws a subtitle row the way a profile card does: the label small and
/// grey on top, the value at body size under it. TGRowDetailAccent paints the
/// value in the accent colour (a phone, a link, a username).
extern NSString *const TGRowLabelAbove;
extern NSString *const TGRowDetailAccent;


#pragma mark - call screen rows

/// UIImage drawn at the trailing edge of any row, replacing that row's
/// accessory: the muted microphone beside a participant, the state mark of a
/// list whose normal accessory says nothing. The screen hands over an image
/// already coloured for the current theme.
extern NSString *const TGRowTrailingImage;

#pragma mark - settings and profile elements

/// The Settings account header and the Appearance chat sample are their own
/// row kinds: both are baked pictures/miniatures, not a text row with an icon.
extern NSString *const TGKindProfileHeader;
extern NSString *const TGKindChatPreview;

/// The account header: avatar, name and the phone/username line. The avatar is
/// either already decoded (TGRowImage) or loaded through TGRowImageLoader once
/// the cell has a width, exactly as the old private header did.
NSMutableDictionary *TGProfileHeaderRow(NSNumber *userId, NSString *name,
		NSString *detail, UIImage *avatar, void (^avatarLoader)(UIImageView *),
		void (^tap)(void));

/// The Appearance sample conversation. Its picture is baked per theme, size and
/// wallpaper, so the row carries no state.
NSMutableDictionary *TGChatPreviewRow(void);

/// The horizontal theme carousel and the 3-column theme grid. Both point at
/// the same baked card cache in TGThemeCardsRowCell.
NSMutableDictionary *TGThemeCardsRow(NSArray *themes, NSString *currentThemeId,
		BOOL showsNames, void (^tap)(NSString *themeId));
NSMutableDictionary *TGThemeGridRow(NSArray *themes, NSString *currentThemeId,
		void (^tap)(NSString *themeId));


#pragma mark - message results and contact index

/// A message search result, the official ChatListSearch message item: the
/// chat's avatar, its name, the hit text on one line and the date. The avatar
/// is TGRowAvatarImage when the screen already has it, otherwise initials from
/// TGRowPeerId.
extern NSString *const TGKindMessageResult;
extern NSString *const TGRowMessageText;
extern NSString *const TGRowMessageDate;

NSMutableDictionary *TGMessageResultRow(NSNumber *chatId, NSString *title,
		NSString *text, NSString *date, void (^tap)(void));

/// A TGListViewController entry ("title", "detail", "destructive", "opens",
/// "tap") as a shared row. Pure so the list's compatibility API is testable
/// without a table.
NSDictionary *TGRowFromListEntry(NSDictionary *entry);
NSArray *TGRowsFromListEntries(NSArray *entries);

/// A contact's section letter: its first letter when that is A-Z or Cyrillic,
/// otherwise "#". Pure for the Contacts index.
NSString *TGContactSectionTitle(NSString *name);



#pragma mark - profile media: picture rows and the tab strip

/// One picture row: a square thumbnail on the left, a title over a subtitle,
/// and one trailing text. Files, music, links and voice in a profile pane are
/// all this row; the screen only says which picture and which words.
extern NSString *const TGKindPicture;
extern NSString *const TGRowPictureImage;       // UIImage, the thumbnail
extern NSString *const TGRowPictureGlyph;       // NSString, fallback glyph name
extern NSString *const TGRowPictureGlyphColour; // UIColor for the fallback glyph
extern NSString *const TGRowPicturePlaceholder; // NSString, initials when no image

/// A picture row with an empty thumbnail to fill in by the caller.
NSMutableDictionary *TGPictureRow(NSString *title, NSString *subtitle,
		void (^tap)(void));

/// The horizontal strip that picks a profile media pane. The screen says which
/// tabs exist and which is selected; the cell keeps its scroll offset across a
/// reload and reports a tap or a hold by kind.
extern NSString *const TGKindTabStrip;
extern NSString *const TGRowTabStripItems;      // NSArray of @{title, kind}
extern NSString *const TGRowTabStripSelected;   // NSString kind
extern NSString *const TGRowTabStripTap;        // void(^)(NSString *kind)
extern NSString *const TGRowTabStripHold;       // void(^)(NSString *kind)
extern NSString *const TGRowTabStripOffset;     // NSNumber, scroll position
extern NSString *const TGRowTabStripOffsetChanged; // void(^)(CGFloat offset)
extern NSString *const TGRowTabStripAccentColour;
extern NSString *const TGRowTabStripSecondaryColour;
extern NSString *const TGRowTabStripBackgroundColour;

NSMutableDictionary *TGTabStripRow(NSArray *tabs, NSString *selected,
		void (^tap)(NSString *kind));



#pragma mark - chat list rows

/// The chat list row and the story strip above it. Both are shared elements:
/// the chat list describes a chat, the strip describes the rows it shows.
extern NSString *const TGKindChatRow;
extern NSString *const TGKindStoryStrip;

/// The trailing accessories of a chat row, boxed as an NSValue under
/// TGRowChatLayout. TGChatListRowGeometry does the arithmetic when the row is
/// built, so -layoutSubviews only applies frames.
typedef struct {
	CGRect badgeFrame;
	CGRect pinFrame;
	CGRect mentionFrame;
	CGFloat previewRight;
	CGFloat badgeWidth;
	/// The width the frames were measured at, so a rotation recomputes them.
	CGFloat width;
	BOOL hasBadge;
	BOOL hasPin;
	BOOL hasMentions;
} TGChatRowAccessories;

extern NSString *const TGRowChatId;             // NSNumber, the chat id/key
extern NSString *const TGRowChatPreview;        // NSString, last message text
extern NSString *const TGRowChatAuthor;         // NSString, "You"/sender name
extern NSString *const TGRowChatDate;           // NSString, already formatted
extern NSString *const TGRowChatCustomEmoji;    // NSArray, preview emoji ranges
extern NSString *const TGRowChatUnread;         // NSNumber count
extern NSString *const TGRowChatMentions;       // NSNumber mention count
extern NSString *const TGRowChatMarkedUnread;   // NSNumber BOOL
extern NSString *const TGRowChatMuted;          // NSNumber BOOL
extern NSString *const TGRowChatPinned;         // NSNumber BOOL
extern NSString *const TGRowChatOnline;         // NSNumber BOOL
extern NSString *const TGRowChatSaved;          // NSNumber BOOL, Saved Messages
extern NSString *const TGRowChatOutgoing;       // NSNumber BOOL, your last message
extern NSString *const TGRowChatRead;           // NSNumber BOOL, read outbox
extern NSString *const TGRowChatAction;         // NSString, typing/recording phrase
extern NSString *const TGRowChatDraft;          // NSString, draft text
extern NSString *const TGRowChatStatusEmojiId;  // NSNumber, emoji status
extern NSString *const TGRowChatAvatarId;       // NSNumber, initials colour key
extern NSString *const TGRowChatAvatarImage;    // UIImage, already decoded
extern NSString *const TGRowChatAvatarGlyph;    // NSString, archive/saved glyph
extern NSString *const TGRowChatLayout;         // NSValue(TGChatRowAccessories)

/// The variants of TGKindChatRow: the archive strip's row and Saved Messages.
extern NSString *const TGChatAvatarGlyphArchive;
extern NSString *const TGChatAvatarGlyphSaved;

/// A chat row from a live chat dictionary. `dateText` is the list's date string
/// because today/week/day formatting belongs to the screen, not the row model.
NSMutableDictionary *TGChatRow(NSDictionary *chat, NSString *dateText);
NSMutableDictionary *TGArchiveChatRow(NSString *title, NSString *subtitle);
NSMutableDictionary *TGSavedMessagesChatRow(NSString *title, NSString *subtitle);

/// The story strip's row. Item dictionaries keep the keys the story reader
/// produces: title, chatId, userId, unread, avatarImage.
extern NSString *const TGRowStories;        // NSArray of story item dictionaries
extern NSString *const TGRowOwnStory;       // NSDictionary, My Story tile
extern NSString *const TGRowStoryAdd;       // void(^)(void)
extern NSString *const TGRowStoryMore;      // void(^)(void)
extern NSString *const TGRowStoryMyTap;     // void(^)(void)
extern NSString *const TGRowStoryMyHold;    // void(^)(void)
extern NSString *const TGRowStoryTap;       // void(^)(NSDictionary *)
extern NSString *const TGRowStoryHold;      // void(^)(NSDictionary *)

NSMutableDictionary *TGStoryStripRow(NSArray *stories, NSDictionary *ownStory);


#ifdef __cplusplus
}
#endif

#endif // TGROWS_H
