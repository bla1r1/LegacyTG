#!/usr/bin/env python3
"""
scripts/ui_standardize.py - Tooling to scaffold and migrate LegacyTG UI to standardized components:
1. TGGeometry.h (C-inline layout slicing & centering without AutoLayout)
2. TGViewController & TGTableViewController with screen states (loading, emptyView, theme)
3. TGTableViewCell (standardized themed cell with title/detail/switch/disclosure)
4. TGFormViewController (unified data-driven forms & settings)
5. Automated migration of controllers and cells.
"""

import sys
import os
import re
import argparse
import glob

def scaffold_geometry(root_dir):
    path = os.path.join(root_dir, "src", "UI", "TGGeometry.h")
    content = """//
// TGGeometry.h - C-inline layout helpers for LegacyTG.
// Zero-allocation frame slicing and centering for 60 FPS manual layout.
//
#ifndef TGGeometry_h
#define TGGeometry_h

#import <UIKit/UIKit.h>
#import <math.h>

/// Slices `height` points from the top of *rect and moves *rect down by (height + spacing).
static inline CGRect TGFrameSliceTop(CGRect *rect, CGFloat height, CGFloat spacing) {
	if (!rect) return CGRectZero;
	CGRect slice = CGRectMake(rect->origin.x, rect->origin.y, rect->size.width, height);
	rect->origin.y += height + spacing;
	rect->size.height = (rect->size.height > height + spacing) ? (rect->size.height - height - spacing) : 0.0f;
	return slice;
}

/// Slices `height` points from the bottom of *rect and shrinks *rect.
static inline CGRect TGFrameSliceBottom(CGRect *rect, CGFloat height, CGFloat spacing) {
	if (!rect) return CGRectZero;
	CGFloat y = rect->origin.y + rect->size.height - height;
	CGRect slice = CGRectMake(rect->origin.x, y, rect->size.width, height);
	rect->size.height = (rect->size.height > height + spacing) ? (rect->size.height - height - spacing) : 0.0f;
	return slice;
}

/// Slices `width` points from the left of *rect and moves *rect right by (width + spacing).
static inline CGRect TGFrameSliceLeft(CGRect *rect, CGFloat width, CGFloat spacing) {
	if (!rect) return CGRectZero;
	CGRect slice = CGRectMake(rect->origin.x, rect->origin.y, width, rect->size.height);
	rect->origin.x += width + spacing;
	rect->size.width = (rect->size.width > width + spacing) ? (rect->size.width - width - spacing) : 0.0f;
	return slice;
}

/// Slices `width` points from the right of *rect and shrinks *rect.
static inline CGRect TGFrameSliceRight(CGRect *rect, CGFloat width, CGFloat spacing) {
	if (!rect) return CGRectZero;
	CGFloat x = rect->origin.x + rect->size.width - width;
	CGRect slice = CGRectMake(x, rect->origin.y, width, rect->size.height);
	rect->size.width = (rect->size.width > width + spacing) ? (rect->size.width - width - spacing) : 0.0f;
	return slice;
}

/// Centers a child size within a container rectangle aligned to integral pixels.
static inline CGRect TGFrameCenterInRect(CGSize size, CGRect container) {
	CGFloat x = (CGFloat)floor(container.origin.x + (container.size.width - size.width) * 0.5f);
	CGFloat y = (CGFloat)floor(container.origin.y + (container.size.height - size.height) * 0.5f);
	return CGRectMake(x, y, size.width, size.height);
}

#endif /* TGGeometry_h */
"""
    with open(path, "w") as f:
        f.write(content)
    print(f"Created: {path}")


def scaffold_base_controllers(root_dir):
    controllers_dir = os.path.join(root_dir, "src", "UI", "Controllers")
    os.makedirs(controllers_dir, exist_ok=True)

    # 1. TGViewController.h
    h_path = os.path.join(controllers_dir, "TGViewController.h")
    with open(h_path, "w") as f:
        f.write("""//
// TGViewController.h - base view controller for LegacyTG.
// Handles iOS 6/7 edges, theme observation, and standard loading/empty states.
//
#import <UIKit/UIKit.h>

@class TGEmptyView;

@interface TGViewController : UIViewController

/// Override in subclass to apply additional theme colors/fonts.
/// Automatically called on viewDidLoad and whenever TGThemeChangedNotification fires.
- (void)applyTheme;

/// Shows or hides a centered activity spinner.
- (void)setLoading:(BOOL)loading;

/// Shows a full-screen empty state view.
- (void)showEmptyWithImage:(UIImage *)image title:(NSString *)title subtitle:(NSString *)subtitle;

/// Removes the empty state view.
- (void)hideEmpty;

@end
""")

    # 2. TGViewController.m
    m_path = os.path.join(controllers_dir, "TGViewController.m")
    with open(m_path, "w") as f:
        f.write("""#import "TGViewController.h"
#import "TGTheme.h"
#import "TGEmptyView.h"
#import "TGGeometry.h"

@interface TGViewController ()
@property (nonatomic, strong) UIActivityIndicatorView *tg_spinner;
@property (nonatomic, strong) TGEmptyView *tg_emptyView;
@end

@implementation TGViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
		self.edgesForExtendedLayout = UIRectEdgeNone;
	}
	[self applyTheme];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(tg_baseThemeDidChange:)
												 name:TGThemeChangedNotification
											   object:nil];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	if (self.tg_spinner && self.tg_spinner.isAnimating) {
		self.tg_spinner.frame = TGFrameCenterInRect(self.tg_spinner.bounds.size, self.view.bounds);
	}
	if (self.tg_emptyView) {
		self.tg_emptyView.frame = self.view.bounds;
	}
}

- (void)tg_baseThemeDidChange:(NSNotification *)note {
	[self applyTheme];
}

- (void)applyTheme {
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)setLoading:(BOOL)loading {
	if (loading) {
		if (!self.tg_spinner) {
			self.tg_spinner = [[UIActivityIndicatorView alloc]
				initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
			self.tg_spinner.hidesWhenStopped = YES;
			[self.view addSubview:self.tg_spinner];
		}
		[self.view bringSubviewToFront:self.tg_spinner];
		self.tg_spinner.frame = TGFrameCenterInRect(self.tg_spinner.bounds.size, self.view.bounds);
		[self.tg_spinner startAnimating];
	} else {
		[self.tg_spinner stopAnimating];
	}
}

- (void)showEmptyWithImage:(UIImage *)image title:(NSString *)title subtitle:(NSString *)subtitle {
	[self.tg_emptyView removeFromSuperview];
	self.tg_emptyView = [TGEmptyView emptyViewWithFrame:self.view.bounds
												 image:image
												 title:title
											  subtitle:subtitle
										   buttonTitle:nil
												target:nil
												action:nil];
	[self.view addSubview:self.tg_emptyView];
}

- (void)hideEmpty {
	[self.tg_emptyView removeFromSuperview];
	self.tg_emptyView = nil;
}

@end
""")

    # 3. TGTableViewController.h
    th_path = os.path.join(controllers_dir, "TGTableViewController.h")
    with open(th_path, "w") as f:
        f.write("""//
// TGTableViewController.h - base table view controller for LegacyTG.
// Handles iOS 6/7 edges, table background/separator, and theme observation.
//
#import <UIKit/UIKit.h>

@class TGEmptyView;

@interface TGTableViewController : UITableViewController

/// Override in subclass to apply additional theme colors/fonts.
/// Automatically called on viewDidLoad and whenever TGThemeChangedNotification fires.
- (void)applyTheme;

/// Shows a full-table empty state view.
- (void)showEmptyWithImage:(UIImage *)image title:(NSString *)title subtitle:(NSString *)subtitle;

/// Removes the empty state view.
- (void)hideEmpty;

@end
""")

    # 4. TGTableViewController.m
    tm_path = os.path.join(controllers_dir, "TGTableViewController.m")
    with open(tm_path, "w") as f:
        f.write("""#import "TGTableViewController.h"
#import "TGTheme.h"
#import "TGEmptyView.h"

@interface TGTableViewController ()
@property (nonatomic, strong) TGEmptyView *tg_emptyView;
@end

@implementation TGTableViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
		self.edgesForExtendedLayout = UIRectEdgeNone;
	}
	[self applyTheme];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(tg_baseThemeDidChange:)
												 name:TGThemeChangedNotification
											   object:nil];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)tg_baseThemeDidChange:(NSNotification *)note {
	[self applyTheme];
	[self.tableView reloadData];
}

- (void)applyTheme {
	TGTheme *theme = [TGTheme shared];
	[theme styleNavigationBar:self.navigationController.navigationBar];
	if (self.tableView.style == UITableViewStyleGrouped) {
		[theme styleGroupedTable:self.tableView];
	} else {
		self.tableView.backgroundColor = [theme listBackgroundColour];
		self.tableView.separatorColor = [theme separatorColour];
	}
}

- (void)showEmptyWithImage:(UIImage *)image title:(NSString *)title subtitle:(NSString *)subtitle {
	self.tg_emptyView = [TGEmptyView emptyViewWithFrame:self.tableView.bounds
												 image:image
												 title:title
											  subtitle:subtitle
										   buttonTitle:nil
												target:nil
												action:nil];
	self.tableView.backgroundView = self.tg_emptyView;
}

- (void)hideEmpty {
	self.tableView.backgroundView = nil;
	self.tg_emptyView = nil;
}

@end
""")
    print("Scaffolded base controllers.")


def scaffold_table_cell(root_dir):
    controls_dir = os.path.join(root_dir, "src", "UI", "Controls")
    os.makedirs(controls_dir, exist_ok=True)

    # 1. TGTableViewCell.h
    h_path = os.path.join(controls_dir, "TGTableViewCell.h")
    with open(h_path, "w") as f:
        f.write("""//
// TGTableViewCell.h - standardized themed table view cell for LegacyTG.
// Automatically styles fonts, colours, disclosure and selection to match TGTheme.
//
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, TGTableCellKind) {
	TGTableCellKindDefault,
	TGTableCellKindSubtitle,
	TGTableCellKindValue1,
};

@interface TGTableViewCell : UITableViewCell

/// Fast initialization with one of the standard styles.
+ (instancetype)cellWithStyle:(TGTableCellKind)kind reuseIdentifier:(NSString *)reuse;

/// Text shortcuts that apply proper TGStyle typography and theme colours.
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;

/// Modifiers
@property (nonatomic, assign) BOOL destructive;
@property (nonatomic, assign) BOOL checked;
@property (nonatomic, assign) BOOL showsDisclosure;

/// Attaches an inline UISwitch with a callback.
- (void)setSwitchOn:(BOOL)on onToggle:(void (^)(BOOL on))onToggle;

/// Forces theme reapplication.
- (void)applyTheme;

@end
""")

    # 2. TGTableViewCell.m
    m_path = os.path.join(controls_dir, "TGTableViewCell.m")
    with open(m_path, "w") as f:
        f.write("""#import "TGTableViewCell.h"
#import "TGTheme.h"
#import "TGStyle.h"
#import "TGIcons.h"

@interface TGTableViewCell ()
@property (nonatomic, copy) void (^switchToggleBlock)(BOOL on);
@property (nonatomic, strong) UISwitch *toggleSwitch;
@end

@implementation TGTableViewCell

+ (instancetype)cellWithStyle:(TGTableCellKind)kind reuseIdentifier:(NSString *)reuse {
	UITableViewCellStyle sysStyle = UITableViewCellStyleDefault;
	if (kind == TGTableCellKindSubtitle) {
		sysStyle = UITableViewCellStyleSubtitle;
	} else if (kind == TGTableCellKindValue1) {
		sysStyle = UITableViewCellStyleValue1;
	}
	return [[self alloc] initWithStyle:sysStyle reuseIdentifier:reuse];
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (self) {
		[self applyTheme];
	}
	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.destructive = NO;
	self.checked = NO;
	self.showsDisclosure = NO;
	self.switchToggleBlock = nil;
	self.accessoryView = nil;
	self.accessoryType = UITableViewCellAccessoryNone;
	self.selectionStyle = UITableViewCellSelectionStyleBlue;
	[self applyTheme];
}

- (void)applyTheme {
	TGTheme *theme = [TGTheme shared];
	self.backgroundColor = [theme listBackgroundColour];
	self.contentView.backgroundColor = [theme listBackgroundColour];

	self.textLabel.font = TGFontRowStrong();
	self.textLabel.textColor = self.destructive ? [theme destructiveColour] : [theme primaryTextColour];
	self.textLabel.backgroundColor = [UIColor clearColor];

	if (self.detailTextLabel) {
		self.detailTextLabel.font = TGFontCaption();
		self.detailTextLabel.textColor = [theme secondaryTextColour];
		self.detailTextLabel.backgroundColor = [UIColor clearColor];
	}
}

- (void)setTitle:(NSString *)title {
	_title = [title copy];
	self.textLabel.text = title;
}

- (void)setDetail:(NSString *)detail {
	_detail = [detail copy];
	if (self.detailTextLabel) {
		self.detailTextLabel.text = detail;
	}
}

- (void)setDestructive:(BOOL)destructive {
	_destructive = destructive;
	self.textLabel.textColor = destructive ? [[TGTheme shared] destructiveColour] : [[TGTheme shared] primaryTextColour];
}

- (void)setChecked:(BOOL)checked {
	_checked = checked;
	self.accessoryType = checked ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

- (void)setShowsDisclosure:(BOOL)showsDisclosure {
	_showsDisclosure = showsDisclosure;
	if (showsDisclosure) {
		self.accessoryView = [[UIImageView alloc] initWithImage:[TGIcons skeuomorphicDisclosureChevron]];
		self.accessoryType = UITableViewCellAccessoryNone;
	} else if (!self.toggleSwitch) {
		self.accessoryView = nil;
		self.accessoryType = UITableViewCellAccessoryNone;
	}
}

- (void)setSwitchOn:(BOOL)on onToggle:(void (^)(BOOL on))onToggle {
	self.switchToggleBlock = onToggle;
	if (!self.toggleSwitch) {
		self.toggleSwitch = [[UISwitch alloc] init];
		[self.toggleSwitch addTarget:self
		                      action:@selector(tg_toggleAction:)
		            forControlEvents:UIControlEventValueChanged];
	}
	self.toggleSwitch.on = on;
	self.accessoryView = self.toggleSwitch;
	self.selectionStyle = UITableViewCellSelectionStyleNone;
}

- (void)tg_toggleAction:(UISwitch *)sender {
	if (self.switchToggleBlock) {
		self.switchToggleBlock(sender.on);
	}
}

@end
""")
    print("Scaffolded TGTableViewCell.")


def scaffold_form_controller(root_dir):
    controllers_dir = os.path.join(root_dir, "src", "UI", "Controllers")
    os.makedirs(controllers_dir, exist_ok=True)

    # 1. TGFormViewController.h
    h_path = os.path.join(controllers_dir, "TGFormViewController.h")
    with open(h_path, "w") as f:
        f.write("""//
// TGFormViewController.h - data-driven form and settings builder for LegacyTG.
// Replaces boilerplate dataSource methods with a declarative section/row model.
//
#import "TGTableViewController.h"

@interface TGFormRow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, assign) BOOL destructive;
@property (nonatomic, assign) BOOL checked;
@property (nonatomic, assign) BOOL disclosure;
@property (nonatomic, assign) BOOL isSwitch;
@property (nonatomic, assign) BOOL switchValue;
@property (nonatomic, copy) void (^onToggle)(BOOL on);
@property (nonatomic, copy) void (^onSelect)(void);

+ (instancetype)rowWithTitle:(NSString *)title detail:(NSString *)detail onSelect:(void (^)(void))onSelect;
+ (instancetype)disclosureWithTitle:(NSString *)title detail:(NSString *)detail onSelect:(void (^)(void))onSelect;
+ (instancetype)switchWithTitle:(NSString *)title value:(BOOL)val onToggle:(void (^)(BOOL on))onToggle;
+ (instancetype)checkWithTitle:(NSString *)title checked:(BOOL)checked onSelect:(void (^)(void))onSelect;
+ (instancetype)actionWithTitle:(NSString *)title destructive:(BOOL)destructive onSelect:(void (^)(void))onSelect;
@end

@interface TGFormSection : NSObject
@property (nonatomic, copy) NSString *header;
@property (nonatomic, copy) NSString *footer;
@property (nonatomic, copy) NSArray<TGFormRow *> *rows;

+ (instancetype)sectionWithHeader:(NSString *)header rows:(NSArray<TGFormRow *> *)rows;
+ (instancetype)sectionWithHeader:(NSString *)header footer:(NSString *)footer rows:(NSArray<TGFormRow *> *)rows;
@end

@interface TGFormViewController : TGTableViewController
@property (nonatomic, copy) NSArray<TGFormSection *> *sections;
- (void)reloadSections;
@end
""")

    # 2. TGFormViewController.m
    m_path = os.path.join(controllers_dir, "TGFormViewController.m")
    with open(m_path, "w") as f:
        f.write("""#import "TGFormViewController.h"
#import "TGTableViewCell.h"
#import "TGTheme.h"
#import "TGStyle.h"

@implementation TGFormRow

+ (instancetype)rowWithTitle:(NSString *)title detail:(NSString *)detail onSelect:(void (^)(void))onSelect {
	TGFormRow *r = [[self alloc] init];
	r.title = title;
	r.detail = detail;
	r.onSelect = onSelect;
	return r;
}

+ (instancetype)disclosureWithTitle:(NSString *)title detail:(NSString *)detail onSelect:(void (^)(void))onSelect {
	TGFormRow *r = [self rowWithTitle:title detail:detail onSelect:onSelect];
	r.disclosure = YES;
	return r;
}

+ (instancetype)switchWithTitle:(NSString *)title value:(BOOL)val onToggle:(void (^)(BOOL on))onToggle {
	TGFormRow *r = [[self alloc] init];
	r.title = title;
	r.isSwitch = YES;
	r.switchValue = val;
	r.onToggle = onToggle;
	return r;
}

+ (instancetype)checkWithTitle:(NSString *)title checked:(BOOL)checked onSelect:(void (^)(void))onSelect {
	TGFormRow *r = [[self alloc] init];
	r.title = title;
	r.checked = checked;
	r.onSelect = onSelect;
	return r;
}

+ (instancetype)actionWithTitle:(NSString *)title destructive:(BOOL)destructive onSelect:(void (^)(void))onSelect {
	TGFormRow *r = [[self alloc] init];
	r.title = title;
	r.destructive = destructive;
	r.onSelect = onSelect;
	return r;
}

@end

@implementation TGFormSection

+ (instancetype)sectionWithHeader:(NSString *)header rows:(NSArray<TGFormRow *> *)rows {
	return [self sectionWithHeader:header footer:nil rows:rows];
}

+ (instancetype)sectionWithHeader:(NSString *)header footer:(NSString *)footer rows:(NSArray<TGFormRow *> *)rows {
	TGFormSection *s = [[self alloc] init];
	s.header = header;
	s.footer = footer;
	s.rows = rows ?: @[];
	return s;
}

@end

@implementation TGFormViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.sections = self.sections ?: @[];
}

- (void)reloadSections {
	[self.tableView reloadData];
}

#pragma mark - Table Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section >= (NSInteger)self.sections.count) return 0;
	return (NSInteger)self.sections[section].rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section >= (NSInteger)self.sections.count) return nil;
	return self.sections[section].header;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section >= (NSInteger)self.sections.count) return nil;
	return self.sections[section].footer;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *cellId = @"TGFormCell";
	TGTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
	if (!cell) {
		cell = [TGTableViewCell cellWithStyle:TGTableCellKindValue1 reuseIdentifier:cellId];
	}

	TGFormRow *row = self.sections[indexPath.section].rows[indexPath.row];
	cell.title = row.title;
	cell.detail = row.detail;
	cell.destructive = row.destructive;
	cell.checked = row.checked;
	cell.showsDisclosure = row.disclosure;

	if (row.isSwitch) {
		[cell setSwitchOn:row.switchValue onToggle:row.onToggle];
	}

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section >= (NSInteger)self.sections.count) return;
	TGFormRow *row = self.sections[indexPath.section].rows[indexPath.row];
	if (row.onSelect) {
		row.onSelect();
	}
}

@end
""")
    print("Scaffolded TGFormViewController.")


def update_tgui_and_makefile(root_dir):
    tgui_h = os.path.join(root_dir, "src", "UI", "TGUI.h")
    if os.path.exists(tgui_h):
        with open(tgui_h, "r") as f:
            content = f.read()
        headers = [
            '#import "TGGeometry.h"',
            '#import "TGViewController.h"',
            '#import "TGTableViewController.h"',
            '#import "TGTableViewCell.h"',
            '#import "TGFormViewController.h"',
        ]
        inserts = [h for h in headers if h not in content]
        if inserts:
            with open(tgui_h, "w") as f:
                f.write("\n".join(inserts) + "\n" + content)
            print("Updated TGUI.h")

    makefile = os.path.join(root_dir, "Makefile")
    if os.path.exists(makefile):
        with open(makefile, "r") as f:
            mcontent = f.read()
        needle = "\tsrc/UI/Controllers/TGListViewController.m \\\n"
        if needle in mcontent:
            new_objs = [
                "\tsrc/UI/Controllers/TGViewController.m \\\n",
                "\tsrc/UI/Controllers/TGTableViewController.m \\\n",
                "\tsrc/UI/Controls/TGTableViewCell.m \\\n",
                "\tsrc/UI/Controllers/TGFormViewController.m \\\n",
            ]
            add_str = "".join([o for o in new_objs if o not in mcontent])
            if add_str:
                mcontent = mcontent.replace(needle, needle + add_str)
                with open(makefile, "w") as f:
                    f.write(mcontent)
                print("Updated Makefile")


def refactor_controller(header_path, impl_path):
    if not os.path.exists(header_path) or not os.path.exists(impl_path):
        return False

    with open(header_path, "r") as f:
        h_content = f.read()

    # Determine kind
    is_table = False
    is_plain = False
    if ": UITableViewController" in h_content:
        is_table = True
    elif ": UIViewController" in h_content:
        is_plain = True
    else:
        return False

    base_class = "TGTableViewController" if is_table else "TGViewController"
    old_class = "UITableViewController" if is_table else "UIViewController"

    # 1. Update Header
    h_content = h_content.replace(f": {old_class}", f": {base_class}")
    import_line = f'#import "{base_class}.h"\n'
    if import_line not in h_content:
        if '#import <UIKit/UIKit.h>' in h_content:
            h_content = h_content.replace('#import <UIKit/UIKit.h>', f'#import <UIKit/UIKit.h>\n{import_line.strip()}')
        else:
            h_content = import_line + h_content

    with open(header_path, "w") as f:
        f.write(h_content)

    # 2. Update Implementation
    with open(impl_path, "r") as f:
        m_content = f.read()

    # Remove redundant edgesForExtendedLayout check
    m_content = re.sub(
        r'\t*if\s*\(\[self\s+respondsToSelector:@selector\(setEdgesForExtendedLayout:\)\]\)\s*\n\t*self\.edgesForExtendedLayout\s*=\s*UIRectEdgeNone;\n?',
        '',
        m_content
    )

    # Remove boilerplate theme notifications in viewDidLoad
    notification_block_pattern = (
        r'(\t*__weak\s+typeof\(self\)\s+weakSelf\s*=\s*self;\s*\n)?'
        r'\t*\[\[NSNotificationCenter\s+defaultCenter\]\s+addObserverForName:TGThemeChangedNotification\s*\n'
        r'[\s\S]*?'
        r'\}\];\n?'
    )
    m_content = re.sub(notification_block_pattern, '', m_content)

    # Remove standalone dealloc if it only does removeObserver
    dealloc_pattern = (
        r'-\s*\(void\)\s*dealloc\s*\{\s*\n'
        r'\t*\[\[NSNotificationCenter\s+defaultCenter\]\s+removeObserver:self\];\s*\n'
        r'\}\s*\n?'
    )
    m_content = re.sub(dealloc_pattern, '', m_content)

    with open(impl_path, "w") as f:
        f.write(m_content)

    print(f"Refactored: {os.path.basename(header_path)} -> {base_class}")
    return True


def status_report(root_dir):
    print(f"=== UI Standardization Status in {root_dir} ===")
    all_vcs = glob.glob(os.path.join(root_dir, "src", "**", "*ViewController.h"), recursive=True)
    table_vc_count = 0
    plain_vc_count = 0
    tg_table_count = 0
    tg_plain_count = 0

    for h in all_vcs:
        with open(h, "r") as f:
            content = f.read()
        if ": UITableViewController" in content:
            table_vc_count += 1
        elif ": UIViewController" in content:
            plain_vc_count += 1
        elif ": TGTableViewController" in content:
            tg_table_count += 1
        elif ": TGViewController" in content:
            tg_plain_count += 1

    total = table_vc_count + plain_vc_count + tg_table_count + tg_plain_count
    migrated = tg_table_count + tg_plain_count
    print(f"Total ViewControllers analyzed: {total}")
    print(f"  Migrated to TG[Table]ViewController: {migrated}")
    print(f"  Pending migration: {table_vc_count + plain_vc_count} ({table_vc_count} table, {plain_vc_count} plain)")


def main():
    parser = argparse.ArgumentParser(description="LegacyTG UI standardization tooling.")
    parser.add_argument("root", nargs="?", default=".", help="Root directory of the repository")
    parser.add_argument("--scaffold", action="store_true", help="Generate standardized base components")
    parser.add_argument("--status", action="store_true", help="Report migration status")
    parser.add_argument("--migrate", nargs="+", help="Migrate specific controller files (path without extension or .m)")
    args = parser.parse_args()

    root_dir = os.path.abspath(args.root)

    if args.status:
        status_report(root_dir)
        return

    # Scaffold
    scaffold_geometry(root_dir)
    scaffold_base_controllers(root_dir)
    scaffold_table_cell(root_dir)
    scaffold_form_controller(root_dir)
    update_tgui_and_makefile(root_dir)

    # Migrate targets if specified
    if args.migrate:
        for t in args.migrate:
            base, _ = os.path.splitext(t)
            refactor_controller(base + ".h", base + ".m")

if __name__ == "__main__":
    main()
