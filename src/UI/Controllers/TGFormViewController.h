//
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
