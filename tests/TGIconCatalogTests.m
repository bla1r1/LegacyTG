// TGIconCatalogTests - every glyph the UI asks for is in the catalogue.
#import "TGIconPaths.h"

@interface TGIconCatalogTests : XCTestCase @end

@implementation TGIconCatalogTests

/// The names TGIcons is asked for by name: the menu and settings rows, the
/// feature glyphs that used to be drawn locally, and the tab/action set.
/// Keep this list in step with the string literals in the code; a name that
/// regresses to nil draws an empty button.
- (void)testEveryAskedNameResolves {
	static const char *names[] = {
		"addStory", "archive", "archiveAvatar", "attach", "backChevron",
		"backspace", "battery", "briefcase", "call", "callIncoming",
		"callMissed", "callOutgoing", "chat", "chats", "checkboxSelected",
		"checkboxUnselected", "chevronDown", "chevronUp", "close",
		"compose", "contacts", "contactsOutline", "copy", "data", "delete",
		"devices", "document", "edit", "endcall", "error", "eye", "faq", "fileDisc",
		"flash", "flashOff", "flip", "folder", "forward", "gallery", "gift",
		"language", "lock", "logout", "mapPinBadge", "mediaDiscPause",
		"mediaDiscPlay", "mention", "microphone", "more", "music", "mute",
		"notifications", "pause", "phoneCall", "pin", "play", "plus",
		"policy", "privacy", "qr", "react", "recent", "recordMicDisc",
		"reply", "savedMessagesAvatar", "search", "searchLens", "select",
		"send", "settings", "settingsOutline", "speaker", "speakerOn",
		"star", "sticker", "telegramAirplane", "ticksMedia",
		"ticksOutgoing", "ticksSingle", "unarchive", "undo", "unmute",
		"unpin", "verifiedBadge", "video",
	};
	for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); i++)
		XCTAssertTrue(TGIconPathNamed(names[i]) != NULL, "%s", names[i]);
}

/// Every table entry has a path and a box. The parser test in
/// TGSVGPathTests checks the shape itself.
- (void)testEveryEntryHasAPathAndABox {
	XCTAssertTrue(TGIconPathCount() >= 84);
	for (size_t i = 0; i < TGIconPathCount(); i++){
		const TGIconPath *icon = TGIconPathAt(i);
		XCTAssertTrue(icon != NULL);
		if (!icon)
			continue;
		XCTAssertTrue(icon->name && icon->name[0], "entry %zu", i);
		XCTAssertTrue(icon->d && icon->d[0], "%s", icon->name);
		XCTAssertTrue(icon->viewW > 0 && icon->viewH > 0, "%s", icon->name);
	}
}

@end
