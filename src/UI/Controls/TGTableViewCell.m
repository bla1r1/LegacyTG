#import "TGTableViewCell.h"
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
