
#import "RNPhotoEditor.h"


@implementation RNPhotoEditor

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE()

NSString *_editImagePath = nil;

RCTResponseSenderBlock _onDoneEditing = nil;
RCTResponseSenderBlock _onCancelEditing = nil;

- (void)doneEditingWithImage:(UIImage *)image {
    if (_onDoneEditing == nil) return;

    NSError* error;

    BOOL isPNG = [_editImagePath.pathExtension.lowercaseString isEqualToString:@"png"];
    NSString* path = _editImagePath;

    if ([path containsString:@"file://"]) {
        NSURL *url = [NSURL URLWithString:_editImagePath];
        path = url.path;
    }

    [isPNG ? UIImagePNGRepresentation(image) : UIImageJPEGRepresentation(image, 0.8) writeToFile:path options:NSDataWritingAtomic error:&error];

    if (error != nil)
        NSLog(@"write error %@", error);

    _onDoneEditing(@[path]);
}

- (void)canceledEditing {
    if (_onCancelEditing == nil) return;

    _onCancelEditing(@[]);
}

RCT_EXPORT_METHOD(Edit:(nonnull NSDictionary *)props onDone:(RCTResponseSenderBlock)onDone onCancel:(RCTResponseSenderBlock)onCancel) {

    dispatch_async(dispatch_get_main_queue(), ^{
        _editImagePath = [props objectForKey: @"path"];

        _onDoneEditing = onDone;
        _onCancelEditing = onCancel;

        PhotoEditorViewController *photoEditor = [[PhotoEditorViewController alloc] initWithNibName:@"PhotoEditorViewController" bundle: [NSBundle bundleForClass:[PhotoEditorViewController class]]];
        // set language
        NSDictionary *languages = [props objectForKey: @"languages"];
        [[TranslationService shared]  initTranslations:languages];
        
        // Process Image for Editing
        UIImage *image = [UIImage imageWithContentsOfFile:_editImagePath];
        if (image == nil) {
            NSURL *url = [NSURL URLWithString:_editImagePath];
            NSData *data = [NSData dataWithContentsOfURL:url];

            image = [UIImage imageWithData:data];
        }

        photoEditor.image = image;

        // Process Stickers
        NSArray *stickers = [props objectForKey: @"stickers"];
        NSMutableArray *imageStickers = [[NSMutableArray alloc] initWithCapacity:stickers.count];

        for (NSString *sticker in stickers) {
            [imageStickers addObject: [UIImage imageNamed: sticker]];
        }

        photoEditor.stickers = imageStickers;

        //Process Controls
        NSArray *hiddenControls = [props objectForKey: @"hiddenControls"];
        NSMutableArray *passHiddenControls = [[NSMutableArray alloc] initWithCapacity:hiddenControls.count];

        for (NSString *hiddenControl in hiddenControls) {
            [passHiddenControls addObject: [[NSString alloc] initWithString: hiddenControl]];
        }

        photoEditor.hiddenControls = passHiddenControls;

        //Process Colors
        NSArray *colors = [props objectForKey: @"colors"];
        NSMutableArray *passColors = [[NSMutableArray alloc] initWithCapacity:colors.count];

        for (NSString *color in colors) {
            [passColors addObject: [self colorWithHexString: color]];
        }

        photoEditor.colors = passColors;

        // Invoke Editor
        photoEditor.photoEditorDelegate = self;

	// The default modal presenting is page sheet in ios 13, not full screen
	if (@available(iOS 13, *)) {
            [photoEditor setModalPresentationStyle: UIModalPresentationFullScreen];
        }

        id<UIApplicationDelegate> app = [[UIApplication sharedApplication] delegate];
        UINavigationController *rootViewController = ((UINavigationController*) app.window.rootViewController);

        if (rootViewController.presentedViewController) {
            [rootViewController.presentedViewController presentViewController:photoEditor animated:YES completion:nil];
            return;
        }

        [rootViewController presentViewController:photoEditor animated:YES completion:nil];
    });
}


- (CGFloat) colorComponentFrom: (NSString *) string start: (NSUInteger) start length: (NSUInteger) length {
    NSString *substring = [string substringWithRange: NSMakeRange(start, length)];
    NSString *fullHex = length == 2 ? substring : [NSString stringWithFormat: @"%@%@", substring, substring];
    unsigned hexComponent;
    [[NSScanner scannerWithString: fullHex] scanHexInt: &hexComponent];
    return hexComponent / 255.0;
}

- (UIColor *) colorWithHexString: (NSString *) hexString {
    NSString *colorString = [[hexString stringByReplacingOccurrencesOfString: @"#" withString: @""] uppercaseString];
    CGFloat alpha, red, blue, green;
    switch ([colorString length]) {
        case 3: // #RGB
            alpha = 1.0f;
            red   = [self colorComponentFrom: colorString start: 0 length: 1];
            green = [self colorComponentFrom: colorString start: 1 length: 1];
            blue  = [self colorComponentFrom: colorString start: 2 length: 1];
            break;
        case 4: // #ARGB
            alpha = [self colorComponentFrom: colorString start: 0 length: 1];
            red   = [self colorComponentFrom: colorString start: 1 length: 1];
            green = [self colorComponentFrom: colorString start: 2 length: 1];
            blue  = [self colorComponentFrom: colorString start: 3 length: 1];
            break;
        case 6: // #RRGGBB
            alpha = 1.0f;
            red   = [self colorComponentFrom: colorString start: 0 length: 2];
            green = [self colorComponentFrom: colorString start: 2 length: 2];
            blue  = [self colorComponentFrom: colorString start: 4 length: 2];
            break;
        case 8: // #AARRGGBB
            alpha = [self colorComponentFrom: colorString start: 0 length: 2];
            red   = [self colorComponentFrom: colorString start: 2 length: 2];
            green = [self colorComponentFrom: colorString start: 4 length: 2];
            blue  = [self colorComponentFrom: colorString start: 6 length: 2];
            break;
        default:
            return nil;
    }
    return [UIColor colorWithRed: red green: green blue: blue alpha: alpha];
}


@end
