//
// TGSettingsPageModels.h - the row list of a Settings page as plain data.
//
// The three pages below are built from state alone, so the host tests can
// check their headers, order and which rows exist without UIKit or TGClient.
// The page code turns these descriptors into the app's row dictionaries and
// attaches the actions; it does not decide the list itself.
//
#ifndef TGSETTINGSPAGEMODELS_H
#define TGSETTINGSPAGEMODELS_H

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Section keys, matching TGSection's dictionary.
extern NSString *const TGPageModelHeader;
extern NSString *const TGPageModelFooter;
extern NSString *const TGPageModelRows;

/// Row keys, matching TGRow's dictionary.
extern NSString *const TGPageModelRowTitle;
extern NSString *const TGPageModelRowDetail;
extern NSString *const TGPageModelRowKind;
extern NSString *const TGPageModelRowIcon;
extern NSString *const TGPageModelRowColour;
extern NSString *const TGPageModelRowOn;
extern NSString *const TGPageModelRowAction;
extern NSString *const TGPageModelRowIndex;

/// Power Saving, in the order EnergySavingSettingsScreen lists its options.
/// The master threshold and the battery row need a settings store this app
/// does not have, so only the switches the app can honour are returned.
/// `vintage`: the device shows still stickers and no wallpaper whatever the
/// switches say, so those two rows are left out.
NSArray *TGPowerSavingPageModel(BOOL stickersOn, BOOL gifsOn, BOOL wallpaperOn, BOOL vintage);

/// Folders: the page intro (folder icon and the official sentence), Create
/// New Folder, the account's folders, the recommended list, then the tag
/// switch. `dev` adds the invite-link row, which official does not have.
NSArray *TGFoldersPageModel(NSArray *folders, NSArray *recommended,
							NSDictionary *chatCounts, BOOL tagsOn, BOOL dev);

/// Proxy: the Use Proxy switch, then Saved Proxies with Add Proxy before the
/// list, as ProxyListSettingsController orders them.
NSArray *TGProxyPageModel(NSArray *proxies, BOOL useProxy, BOOL connected,
						  BOOL dev);

/// The Chat Folders list section: after the intro, folders below the Create
/// New Folder row.
#define TGFoldersPageListSection 1
#define TGFoldersPageFirstFolderRow 1

/// The folder a row of the Chat Folders page shows, or -1 for any other row
/// (the intro, Create New Folder, Add Folder, suggestions, the switch).
NSInteger TGFoldersPageFolderIndex(NSInteger section, NSInteger row,
								   NSUInteger folderCount);

/// Where a dragged folder may land: inside the folder rows, whatever row the
/// finger is over.
NSInteger TGFoldersPageDropRow(NSInteger proposedSection, NSInteger proposedRow,
							   NSUInteger folderCount);

/// Values on the account pages: frozen or not, a subscription's state, the
/// minimum age, a notification sound's name, a notification group's label.
NSString *TGFreezeDetail(NSDictionary *state);
NSString *TGSubscriptionDetail(NSDictionary *record);
NSString *TGAgeVerificationDetail(NSDictionary *parameters);
NSString *TGSoundName(NSDictionary *sound);
NSString *TGNotificationGroupLabel(NSString *type);

/// The help under a privacy rule's choices, in the pack's words. Calls and
/// forwards get none: the pack has no sentence for them, and an invented one
/// stays English in every language.
NSString *TGPrivacyRuleFooterText(NSString *setting);

/// The profile photo rule offers a public photo once someone is kept from
/// the real one: anyone but everybody, or a Never Allow list.
BOOL TGPrivacyOffersPublicPhoto(NSString *setting, NSString *ruleType, NSUInteger neverCount);

/// A byte value without a trailing zero fraction, the shape official uses on
/// the auto-download rows ("120 MB", not "120.0 MB").
NSString *TGPageModelCompactBytes(long long bytes);

/// Every session but this device's, keeping the ones whose isUnconfirmed
/// matches: incomplete sign-ins, confirmed ones, or both. The list order stays.
NSArray *TGSessionsOtherThanCurrent(NSArray *sessions, BOOL unconfirmed,
									BOOL confirmed);

/// The pack key for a call's kind: Missed, Outgoing or Incoming Call.
NSString *TGRecentCallKindKey(BOOL missed, BOOL outgoing);
/// One Recent Calls row as CallListCallItem lays it out: the kind of call
/// (and its length) under the name, the date alone on the right. All three
/// strings arrive translated and formatted. Keys "subtitle", "trailing".
NSDictionary *TGRecentCallRowText(NSString *kind, BOOL missed, NSString *when,
		NSString *duration);

#ifdef __cplusplus
}
#endif

#endif // TGSETTINGSPAGEMODELS_H
