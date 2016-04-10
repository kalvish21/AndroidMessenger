//
//  CNTestView.m
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 4/9/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

#import "CNTestView.h"

@implementation CNTestView

- (CNSplitViewToolbar*)getCNToolBar {
    NSMenu *contextMenu = [[NSMenu alloc] init];
    [contextMenu addItemWithTitle:@"Add new Item" action:@selector(contextMenuItemSelection:) keyEquivalent:@""];
    [contextMenu addItemWithTitle:@"Add new Group" action:@selector(contextMenuItemSelection:) keyEquivalent:@""];
    CNSplitViewToolbarButton *button1 = [[CNSplitViewToolbarButton alloc] initWithContextMenu:contextMenu];
    button1.imageTemplate = CNSplitViewToolbarButtonImageTemplateAdd;
    
    CNSplitViewToolbarButton *button2 = [[CNSplitViewToolbarButton alloc] init];
    button2.imageTemplate = CNSplitViewToolbarButtonImageTemplateRemove;
    
    CNSplitViewToolbarButton *button3 = [[CNSplitViewToolbarButton alloc] init];
    button3.imageTemplate = CNSplitViewToolbarButtonImageTemplateLockUnlocked;
    button3.imagePosition = NSImageRight;
    button3.title = @"Lock";
    
    CNSplitViewToolbarButton *button4 = [[CNSplitViewToolbarButton alloc] init];
    button4.imageTemplate = CNSplitViewToolbarButtonImageTemplateRefresh;
    button4.title = @"Refresh";
    
    NSTextField *textField = [[NSTextField alloc] init];
    [textField setBezeled:YES];
    [textField setBezeled:NSTextFieldRoundedBezel];
    [textField setToolbarItemWidth:120.0];
    
    NSPopUpButton *popupButton = [[NSPopUpButton alloc] init];
    [popupButton setToolbarItemWidth:120];
    [popupButton addItemsWithTitles:@[@"Chelsea Manning...", @"Edward Snowden...", @"Aaron Swartz..."]];
    [[popupButton cell] setControlSize:NSSmallControlSize];
    
    NSSlider *slider = [[NSSlider alloc] init];
    [slider setToolbarItemWidth:120.0];
    [[slider cell] setControlSize:NSSmallControlSize];
    
    
    CNSplitViewToolbar *toolbar = [[CNSplitViewToolbar alloc] init];
    [toolbar addItem:button1 align:CNSplitViewToolbarItemAlignLeft];
    [toolbar addItem:button2 align:CNSplitViewToolbarItemAlignLeft];
    [toolbar addItem:button3 align:CNSplitViewToolbarItemAlignRight];
    [toolbar addItem:button4 align:CNSplitViewToolbarItemAlignRight];
    
    return toolbar;
}

+(id)hyperlinkFromString:(NSString*)inString withURL:(NSURL*)aURL
{
    NSMutableAttributedString* attrString = [[NSMutableAttributedString alloc] initWithString: inString];
    NSRange range = NSMakeRange(0, [attrString length]);
    
    [attrString beginEditing];
    [attrString addAttribute:NSLinkAttributeName value:[aURL absoluteString] range:range];
    [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:range];
    [attrString addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:13] range:range];
    [attrString addAttribute:NSCursorAttributeName value:NSCursor.pointingHandCursor range:range];
    [attrString addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:NSUnderlineStyleSingle] range:range];
    [attrString endEditing];
    
    return attrString;
}

@end
