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
NSArray *TGPowerSavingPageModel(BOOL stickersOn, BOOL gifsOn, BOOL wallpaperOn);

/// Folders: Create New Folder, the account's folders, the recommended list,
/// then the tag switch. `dev` adds the invite-link row, which official does
/// not have.
NSArray *TGFoldersPageModel(NSArray *folders, NSArray *recommended,
							NSDictionary *chatCounts, BOOL tagsOn, BOOL dev);

/// Proxy: the Use Proxy switch, then Saved Proxies with Add Proxy before the
/// list, as ProxyListSettingsController orders them.
NSArray *TGProxyPageModel(NSArray *proxies, BOOL useProxy, BOOL connected,
						  BOOL dev);

/// A byte value without a trailing zero fraction, the shape official uses on
/// the auto-download rows ("120 MB", not "120.0 MB").
NSString *TGPageModelCompactBytes(long long bytes);

#ifdef __cplusplus
}
#endif

#endif // TGSETTINGSPAGEMODELS_H
