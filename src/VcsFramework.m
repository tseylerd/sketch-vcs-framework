#import "VcsFramework.h"
#import <Foundation/Foundation.h>
#import "MSDocument.h"
@import AppKit;
@import JavaScriptCore;

@interface TextFieldDelegate : NSTextField
@property NSButton *okButton;
@end

@implementation TextFieldDelegate
- (void)textDidChange:(NSNotification *)notification {
    NSTextView *textField = [notification object];
    if ([[textField string] isEqualToString:@""]) {
        [_okButton setEnabled:false];
    }
    else {
        [_okButton setEnabled:true];
    }
    [super textDidChange:notification];
}

@end

@implementation VcsFramework
+ (void) showAlert: (NSString*) message {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:@"Git Plugin"];
    [alert setInformativeText:message];
    [alert runModal];
}

+ (NSString*) getUserInput: (NSString*) message {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:message];
    [alert addButtonWithTitle:@"Ok"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSArray *buttons = [alert buttons];
    NSButton *okButton = (NSButton*)([buttons objectAtIndex:0]);
    [okButton setEnabled:false];
    
    TextFieldDelegate *input = [[TextFieldDelegate alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    [input setOkButton:okButton];
    [input setStringValue:@""];
    [alert setAccessoryView:input];
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        NSString *inputString = [input stringValue];
        return inputString;
    }
    else {
        return nil;
    }
}

+ (void) exec: (NSArray*) args client: (NSURL *)url_client document: (MSDocument *) document {
    NSString *launchPath = [NSString stringWithFormat:@"%@/%@", url_client.path.stringByRemovingPercentEncoding, @"run-client.sh"];
    [VcsFramework showAlert:launchPath];
    NSArray *firstArgs = [NSArray arrayWithObjects: launchPath, nil];
    NSArray *allArgs = [firstArgs arrayByAddingObjectsFromArray:args];
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    [task setArguments:allArgs];
    [task setCurrentDirectoryPath:url_client.path];
    NSPipe* out_pipe = [NSPipe pipe];
    NSPipe* err_pipe = [NSPipe pipe];
    [task setStandardOutput:out_pipe];
    [task setStandardError:err_pipe];
    
    [task setTerminationHandler: ^(NSTask *task){
        NSData* errData = [[err_pipe fileHandleForReading] readDataToEndOfFile];
        NSData* data = [[out_pipe fileHandleForReading] readDataToEndOfFile];
        NSString *message = @"";
        if (errData != nil && [errData length]) {
            message = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding];
        } else if (data != nil && [data length]) {
            message = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
        if ([message length]) {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [VcsFramework showAlert:message];
                NSURL* url = document.fileURL;
                [document readFromURL:url ofType:document.fileType error:nil];
            });
        }
    }];
    [task launchAndReturnError:nil];
}

+ (void) runCommand: (MSDocument*) document plugin: (NSObject*) plugin command: (NSString *) command {
    @try {
        NSURL* documentUrl = document.fileURL;
    
        if (![[documentUrl scheme] isEqualToString:@"file"]) {
            [VcsFramework showAlert:[NSString stringWithFormat:@"%@%@", @"Only local files can be under version control.", documentUrl.absoluteString]];
            return;
        }
        
        NSString* documentPath = [[documentUrl path] stringByRemovingPercentEncoding];
        [VcsFramework showAlert:documentPath];

        SEL selectorUrlForResourceNamed = NSSelectorFromString(@"urlForResourceNamed:");
        NSURL* (*urlForResourceNamed)(id, SEL, id) = (void *)[plugin methodForSelector:selectorUrlForResourceNamed];
        NSURL* url_client = urlForResourceNamed(plugin, selectorUrlForResourceNamed, @"pack");
        
        if ([command isEqualToString:@"start_id"]) {
            [VcsFramework exec: [NSArray arrayWithObjects:@"start", documentPath, nil] client:url_client document: document];
        }
        else if ([command isEqualToString:@"stop_id"]) {
            [VcsFramework exec: [NSArray arrayWithObjects:@"stop", documentPath, nil] client:url_client document: document];
        }
        else if ([command isEqualToString:@"pull_id"]) {
            [VcsFramework exec: [NSArray arrayWithObjects:@"pull", documentPath, nil] client:url_client document: document];
        } else if ([command isEqualToString:@"push_id"]) {
            NSString* commitMessage = [VcsFramework getUserInput:@"Enter commit message:"];
            if (commitMessage == nil) {
                return;
            }
            [VcsFramework exec: [NSArray arrayWithObjects:@"push", documentPath, commitMessage, nil] client:url_client document: document];
        }
    }
    @catch (NSException *e) {
        NSLog(@"%@", [e reason]);
        [VcsFramework showAlert:[e reason]];
    }
}

+ (IMP) documentMethod: (NSObject*) document plugin: (NSObject*) plugin method: (NSString*) methodName {
    SEL resourceUrlSelector = NSSelectorFromString(methodName);
    IMP resourceUrlImplementation = [plugin methodForSelector:resourceUrlSelector];
    return resourceUrlImplementation;
}
@end
