#import "TGListViewController.h"

@implementation TGListViewController

- (NSArray *)rows {
	return self.listRows;
}

- (void)setRows:(NSArray *)rows {
	self.listRows = rows;
}

- (void)setListTitle:(NSString *)listTitle {
	_listTitle = [listTitle copy];
	self.title = listTitle;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if (self.listTitle.length)
		self.title = self.listTitle;
}

@end
