//
// TGPresentRules.m
//
#import "TGPresentRules.h"
#import "TGStyle.h"

typedef struct {
	const char *name;
	const char *title;   ///< Common.* English, NULL for a glyph
	const char *glyph;   ///< TGIcons name, NULL for words
	const char *label;
	BOOL primary;
	TGBarSide side;
} TGBarRoleRule;

// Indexed by TGBarRole. Official: Common.Cancel / Common.Close on the left of
// a modal, Common.Done (bold) and Common.Edit on the right, the ⋯ button
// opening a context menu, .add and .action as icons (ItemListController).
// Add is the system + (UIBarButtonSystemItemAdd): iOS 6 draws it in the
// bar's own chrome, and the screens already use it.
static const TGBarRoleRule kRules[TGBarRoleCount] = {
	[TGBarRoleBack]   = {"back",   "Back",   NULL,      "Back",   NO,  TGBarSideLeft},
	[TGBarRoleCancel] = {"cancel", "Cancel", NULL,      "Cancel", NO,  TGBarSideLeft},
	[TGBarRoleDone]   = {"done",   "Done",   NULL,      "Done",   YES, TGBarSideRight},
	[TGBarRoleEdit]   = {"edit",   "Edit",   NULL,      "Edit",   NO,  TGBarSideRight},
	[TGBarRoleClose]  = {"close",  "Close",  NULL,      "Close",  NO,  TGBarSideLeft},
	[TGBarRoleMore]   = {"more",   NULL,     "more",    "More",   NO,  TGBarSideRight},
	[TGBarRoleAdd]    = {"add",    NULL,     NULL,      "Add",    NO,  TGBarSideRight},
	[TGBarRoleShare]  = {"share",  NULL,     "forward", "Share",  NO,  TGBarSideRight},
	[TGBarRoleSearch] = {"search", NULL,     NULL,      "Search", NO,  TGBarSideRight},
	[TGBarRoleCompose]= {"compose",NULL,     NULL,      "Compose",NO,  TGBarSideRight},
	[TGBarRoleAddStory]={"addStory",NULL,    "addStory","Add Story",NO, TGBarSideRight},
};

static const TGBarRoleRule *TGRule(TGBarRole role) {
	if (role < 0 || role >= TGBarRoleCount)
		return &kRules[TGBarRoleClose];
	return &kRules[role];
}

static NSString *TGString(const char *s) {
	return s ? @(s) : nil;
}

NSString *TGBarRoleTitle(TGBarRole role) { return TGString(TGRule(role)->title); }
NSString *TGBarRoleGlyph(TGBarRole role) { return TGString(TGRule(role)->glyph); }
NSString *TGBarRoleLabel(TGBarRole role) { return TGString(TGRule(role)->label); }
NSString *TGBarRoleName(TGBarRole role) { return TGString(TGRule(role)->name); }
BOOL TGBarRoleIsPrimary(TGBarRole role) { return TGRule(role)->primary; }
BOOL TGBarRoleIsBare(TGBarRole role) { return role == TGBarRoleAddStory; }

BOOL TGBarRoleIsSystemItem(TGBarRole role) {
	return role == TGBarRoleAdd || role == TGBarRoleSearch || role == TGBarRoleCompose;
}
TGBarSide TGBarRoleSide(TGBarRole role) { return TGRule(role)->side; }

BOOL TGModalDismissRole(TGModalKind kind, TGBarRole *role) {
	TGBarRole r;
	switch (kind){
	case TGModalForm: r = TGBarRoleCancel; break;
	case TGModalInfo: r = TGBarRoleClose; break;
	default: return NO;
	}
	if (role)
		*role = r;
	return YES;
}

CGPoint TGMenuAnchorUnder(CGRect source) {
	return CGPointMake(CGRectGetMidX(source), CGRectGetMaxY(source));
}

CGRect TGBarItemFallbackRect(CGRect bar, TGBarSide side) {
	CGFloat side_ = bar.size.height;
	CGFloat x = side == TGBarSideLeft
			? CGRectGetMinX(bar) + TGMetricPadSmall
			: CGRectGetMaxX(bar) - TGMetricPadSmall - side_;
	return CGRectMake(x, CGRectGetMinY(bar), side_, side_);
}

BOOL TGSystemPickerNeedsPopover(BOOL pad, NSInteger systemMajor) {
	return pad && systemMajor < 8;
}

NSString *TGMenuGlyphForTitle(NSString *title) {
	if (![title isKindOfClass:NSString.class] || !title.length)
		return nil;
	NSString *word = [[title componentsSeparatedByString:@" "].firstObject lowercaseString];
	static NSDictionary *glyphs;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		glyphs = @{@"delete" : @"delete", @"remove" : @"delete", @"clear" : @"delete",
				   @"edit" : @"edit", @"rename" : @"edit", @"copy" : @"copy",
				   @"pin" : @"pin", @"unpin" : @"unpin", @"mute" : @"mute",
				   @"unmute" : @"unmute", @"archive" : @"archive", @"unarchive" : @"unarchive",
				   @"reply" : @"reply", @"forward" : @"forward", @"share" : @"forward"};
	});
	return glyphs[word];
}

NSArray *TGMenuItems(NSArray *titles, NSInteger destructiveIndex) {
	NSMutableArray *items = [NSMutableArray arrayWithCapacity:titles.count];
	[titles enumerateObjectsUsingBlock:^(NSString *title, NSUInteger i, BOOL *stop){
		NSMutableDictionary *item = [NSMutableDictionary dictionaryWithObject:title forKey:@"title"];
		NSString *glyph = TGMenuGlyphForTitle(title);
		if (glyph)
			item[@"icon"] = glyph;
		if ((NSInteger)i == destructiveIndex)
			item[@"destructive"] = @YES;
		[items addObject:item];
	}];
	return items;
}

NSArray *TGListEntries(NSArray *lines, NSInteger destructiveIndex) {
	NSMutableArray *entries = [NSMutableArray arrayWithCapacity:lines.count];
	[lines enumerateObjectsUsingBlock:^(id line, NSUInteger i, BOOL *stop){
		NSString *text = [line isKindOfClass:NSString.class] ? line : [line description];
		NSMutableDictionary *entry = [NSMutableDictionary dictionary];
		NSRange dot = [text rangeOfString:@" · "];
		if (dot.location != NSNotFound && dot.location > 0){
			entry[@"title"] = [text substringToIndex:dot.location];
			entry[@"detail"] = [text substringFromIndex:NSMaxRange(dot)];
		} else {
			entry[@"title"] = text;
		}
		if ((NSInteger)i == destructiveIndex)
			entry[@"destructive"] = @YES;
		[entries addObject:entry];
	}];
	return entries;
}
