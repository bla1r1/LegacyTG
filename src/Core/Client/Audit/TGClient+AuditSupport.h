#import "TGClient+Base.h"

// C helpers shared by the audit categories.
NSString *TGAuditError(NSDictionary *result);
BOOL TGAuditFailed(NSDictionary *result);
void TGAuditExecute(TGClient *client, NSDictionary *request, void (^completion)(NSDictionary *));
NSString *TGAuditShortType(id value);
NSString *TGAuditPrefixedType(NSString *prefix, NSString *value);
NSString *TGAuditString(NSDictionary *dictionary, NSString *key);
NSNumber *TGAuditNumber(NSDictionary *dictionary, NSString *key);
NSDictionary *TGAuditUser(NSDictionary *user);
NSDictionary *TGAuditSender(NSString *kind, int64_t identifier);
NSDictionary *TGAuditSticker(NSDictionary *sticker);
NSDictionary *TGAuditJsonValue(id value);
NSDictionary *TGAuditReportResult(NSDictionary *result);
NSDictionary *TGAuditWebAppTheme(void);
NSDictionary *TGAuditWebAppParameters(NSString *mode);
NSDictionary *TGAuditButtonSource(int64_t chatId, int64_t messageId);
