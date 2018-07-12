#ifndef MSDocument_h
#define MSDocument_h

#import <AppKit/NSDocument.h>

@interface MSDocument: NSDocument
- (void)performPostPageSwitchUpdates;
- (BOOL)revertToContentsOfURL:(id)arg1 ofType:(id)arg2 error:(id *)arg3;
- (BOOL)readDocumentFromURL:(id)arg1 ofType:(id)arg2 error:(id *)arg3;
- (void)wireDocumentDataToUI;
@end

#endif
