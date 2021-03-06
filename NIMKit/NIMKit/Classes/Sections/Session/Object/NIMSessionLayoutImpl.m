//
//  NIMSessionLayout.m
//  NIMKit
//
//  Created by chris on 2016/11/8.
//  Copyright © 2016年 NetEase. All rights reserved.
//

#import "NIMSessionLayoutImpl.h"
#import "UITableView+NIMScrollToBottom.h"
#import "NIMMessageCell.h"
#import "NIMGlobalMacro.h"
#import "NIMKitUIConfig.h"
#import "NIMSessionTableAdapter.h"
#import "UIView+NIM.h"

@interface NIMSessionLayoutImpl(){
    NSMutableArray *_inserts;
    CGFloat _inputViewHeight;
}

@property (nonatomic,strong)  UITableView *tableView;

@property (nonatomic,strong)  UIRefreshControl *refreshControl;

@property (nonatomic,strong)  NIMSession  *session;

@property (nonatomic,assign)  CGRect viewRect;

@property (nonatomic,strong)  id<NIMSessionConfig> sessionConfig;

@property (nonatomic,weak)    id<NIMSessionLayoutDelegate> delegate;

@end

@implementation NIMSessionLayoutImpl

- (instancetype)initWithSession:(NIMSession *)session
                      tableView:(UITableView *)tableView
                         config:(id<NIMSessionConfig>)sessionConfig
{
    self = [super init];
    if (self) {
        _tableView     = tableView;
        _sessionConfig = sessionConfig;
        _session       = session;
        _inserts       = [[NSMutableArray alloc] init];
        
        [self setupRefreshControl];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuDidHide:) name:UIMenuControllerDidHideMenuNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)reloadTable
{
    [self.tableView reloadData];
}

- (void)resetLayout
{
    [self adjustTableView];
}

- (void)layoutAfterRefresh
{
    [self.refreshControl endRefreshing];
    
    CGFloat offset  = self.tableView.contentSize.height - self.tableView.contentOffset.y;
    [self.tableView reloadData];
    CGFloat offsetYAfterLoad = self.tableView.contentSize.height - offset;
    CGPoint point  = self.tableView.contentOffset;
    point.y = offsetYAfterLoad;
    [self.tableView setContentOffset:point animated:NO];
}

- (void)changeLayout:(CGFloat)inputViewHeight
{
    BOOL change = _inputViewHeight != inputViewHeight;
    if (change)
    {
        _inputViewHeight = inputViewHeight;
        [self adjustTableView];
    }
}

- (void)adjustTableView
{
    BOOL viewRectChanged = !CGRectEqualToRect(_viewRect, self.tableView.superview.frame);
    [self setViewRect:self.tableView.superview.frame];
    
    CGRect rect = [_tableView frame];
    rect.origin.y = 0;
    rect.size.height = self.viewRect.size.height - _inputViewHeight;
    BOOL tableChanged = !CGRectEqualToRect(_tableView.frame, rect);
    if (tableChanged)
    {
        [_tableView setFrame:rect];
    }
    if (tableChanged || viewRectChanged)
    {
        [_tableView reloadData];
        [_tableView nim_scrollToBottom:YES];
    }
}


#pragma mark - Notification
- (void)menuDidHide:(NSNotification *)notification
{
    [UIMenuController sharedMenuController].menuItems = nil;
}

#pragma mark - Private

- (void)calculateContent:(NIMMessageModel *)model{
    [model contentSize:self.tableView.nim_width];
}

- (void)setupRefreshControl
{
    self.refreshControl = [[UIRefreshControl alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
    [self.tableView addSubview:_refreshControl];
    [self.refreshControl addTarget:self action:@selector(headerRereshing:) forControlEvents:UIControlEventValueChanged];
}

- (void)headerRereshing:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(onRefresh)])
    {
        [self.delegate onRefresh];
    }
}



- (void)insert:(NSArray<NSIndexPath *> *)indexPaths animated:(BOOL)animated
{
    if (!indexPaths.count)
    {
        return;
    }

    NSMutableArray *addIndexPathes = [NSMutableArray array];
    [indexPaths enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[obj integerValue] inSection:0];
        [addIndexPathes addObject:indexPath];
    }];
    
    [self.tableView beginUpdates];
    [self.tableView insertRowsAtIndexPaths:addIndexPathes withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView endUpdates];
    [self.tableView nim_scrollToBottom:animated];

}

- (void)remove:(NSArray<NSIndexPath *> *)indexPaths
{
    [self.tableView beginUpdates];
    [self.tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
    [self.tableView endUpdates];
}


- (void)update:(NSIndexPath *)indexPath
{
    NIMMessageCell *cell = (NIMMessageCell *)[self.tableView cellForRowAtIndexPath:indexPath];
    if (cell) {
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        CGFloat scrollOffsetY = self.tableView.contentOffset.y;
        [self.tableView setContentOffset:CGPointMake(self.tableView.contentOffset.x, scrollOffsetY) animated:NO];
    }
}

- (BOOL)canInsertChatroomMessages
{
    return !self.tableView.isDecelerating && !self.tableView.isDragging;
}

@end
