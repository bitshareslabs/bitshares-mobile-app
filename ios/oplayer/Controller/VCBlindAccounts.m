//
//  VCBlindAccounts.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCBlindAccounts.h"
#import "VCBlindAccountImport.h"
#import "ViewBlindAccountCell.h"

#import "HDWallet.h"

@interface VCBlindAccounts ()
{
    WsPromiseObject*        _result_promise;
    
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    UILabel*                _lbEmpty;
}

@end

@implementation VCBlindAccounts

-(void)dealloc
{
    _dataArray = nil;
    _lbEmpty = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _result_promise = nil;
}

- (id)initWithResultPromise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self){
        _result_promise = result_promise;
        _dataArray = [NSMutableArray array];
    }
    return self;
}

- (BOOL)isSelectMode
{
    return !!_result_promise;
}

- (void)refreshUI:(BOOL)reload
{
    //  获取所有隐私账户
    [_dataArray removeAllObjects];
    
    //    id blind_account = @{
    //        @"public_key": @"",
    //        @"alias_name": @"",
    //        @"parent_key": @"",
    //        @"child_key_index": @0
    //    };
    NSMutableDictionary* sections = [NSMutableDictionary dictionary];
    NSMutableArray* child_list = [NSMutableArray array];
    
    id accounts_hash = [[AppCacheManager sharedAppCacheManager] getAllBlindAccounts];
    
    for (id public_key in accounts_hash) {
        id blind_account = [accounts_hash objectForKey:public_key];
        assert(blind_account);
        NSString* parent_key = [blind_account objectForKey:@"parent_key"];
        if (parent_key && ![parent_key isEqualToString:@""]) {
            //  子账号
            [child_list addObject:blind_account];
        } else {
            //  主账号
            sections[public_key] = @{
                @"main": blind_account,
                @"child": [NSMutableArray array]
            };
        }
    }
    
    for (id blind_account in child_list) {
        NSString* parent_key = [blind_account objectForKey:@"parent_key"];
        assert(parent_key && ![parent_key isEqualToString:@""]);
        id section_item = [sections objectForKey:parent_key];
        NSAssert(section_item, @"unknown child blind account.");
        [section_item[@"child"] addObject:blind_account];
    }
    
    //  排序：主账号根据地址排序、子账号根据索引升序排序。
    [_dataArray addObjectsFromArray:[sections allValues]];
    [_dataArray sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        id c1 = [[obj1 objectForKey:@"main"] objectForKey:@"public_key"];
        id c2 = [[obj2 objectForKey:@"main"] objectForKey:@"public_key"];
        return [c1 compare:c2];
    })];
    for (id section_item in _dataArray) {
        NSMutableArray* child = section_item[@"child"];
        if (child && [child count] > 0) {
            [child sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                NSInteger c1 = [[obj1 objectForKey:@"child_key_index"] integerValue];
                NSInteger c2 = [[obj2 objectForKey:@"child_key_index"] integerValue];
                return c1 - c2;
            })];
        }
    }
    
    //  刷新可见性
    _mainTableView.hidden = [_dataArray count] == 0;
    _lbEmpty.hidden = !_mainTableView.hidden;
    
    if (reload && !_mainTableView.hidden) {
        [_mainTableView reloadData];
    }
}

- (void)onImportBlindOutputReceipt
{
    //  TODO:6.0 lang
    [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self
                                                       message:nil
                                                        cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                         items:@[@"导入隐私账户",
                                                                 @"创建隐私账户"]
                                                      callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
     {
        if (buttonIndex != cancelIndex){
            if (buttonIndex == 0) {
                //  TODO:6.0
                WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
                VCBlindAccountImport* vc = [[VCBlindAccountImport alloc] initWithResultPromise:result_promise];
                [self pushViewController:vc vctitle:@"导入隐私账户" backtitle:kVcDefaultBackTitleName];
                [result_promise then:^id(id blind_account) {
                    if (blind_account) {
                        //  刷新
                        [self refreshUI:YES];
                    }
                    return nil;
                }];
            } else {
                //  TODO:6.0
                [OrgUtils makeToast:@"创建 TODO:"];
            }
        }
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  右上角按钮（地址管理模式才存在、选择模式不存在。）
    if (![self isSelectMode]) {
        UIBarButtonItem* addBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                target:self
                                                                                action:@selector(onImportBlindOutputReceipt)];
        addBtn.tintColor = [ThemeManager sharedThemeManager].navigationBarTextColor;
        self.navigationItem.rightBarButtonItem = addBtn;
    }
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNaviAndPageBar];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 空
    _lbEmpty = [self genCenterEmptyLabel:rect txt:@"没有隐私账户，可点击右上角创建或恢复隐私账户。"];
    _lbEmpty.hidden = YES;
    [self.view addSubview:_lbEmpty];
    
    [self refreshUI:NO];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_dataArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    //  主账号 + n个子账号
    return 1 + [[[_dataArray objectAtIndex:section] objectForKey:@"child"] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat baseHeight = 8.0 + 28 + 24;
    
    return baseHeight;
}

- (id)_getBlindAccount:(NSIndexPath*)indexPath
{
    id section_item = [_dataArray objectAtIndex:indexPath.section];
    if (indexPath.row == 0) {
        return [section_item objectForKey:@"main"];
    } else {
        return [[section_item objectForKey:@"child"] objectAtIndex:indexPath.row - 1];
    }
}

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 10.0f;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 10.0f;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return @" ";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* identify = @"id_blind_account_cell";
    ViewBlindAccountCell* cell = (ViewBlindAccountCell*)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[ViewBlindAccountCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        if ([self isSelectMode]) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    cell.showCustomBottomLine = YES;
    cell.row = indexPath.section;
    [cell setItem:[self _getBlindAccount:indexPath]];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        [self onCellClicked:[self _getBlindAccount:indexPath] section:indexPath.section];
    }];
}

- (void)onCellClicked:(id)blind_account section:(NSInteger)section
{
    if ([self isSelectMode]) {
        //  选择 & 返回
        [_result_promise resolve:blind_account];
        [self closeOrPopViewController];
    } else {
        //  管理
        [self onCellActionPopAction:blind_account section:section];
    }
}

- (void)onCellActionPopAction:(id)blind_account section:(NSInteger)section
{
    assert(blind_account);
    
    enum
    {
        kActionTypeGenChildKey = 0,
        kActionTypeCopyKey
    };
    
    NSMutableArray* actions = [NSMutableArray array];
    
    //  TODO:6.0 lang
    NSString* parent_key = [blind_account objectForKey:@"parent_key"];
    if (!parent_key || [parent_key isEqualToString:@""]) {
        //  主账号
        [actions addObject:@{@"type":@(kActionTypeGenChildKey), @"name":@"创建子账户"}];
    }
    [actions addObject:@{@"type":@(kActionTypeCopyKey), @"name":@"复制地址"}];
    
    [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self message:nil
                                                        cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                         items:actions
                                                           key:@"name"
                                                      callback:^(NSInteger buttonIndex, NSInteger cancelIndex) {
        if (buttonIndex != cancelIndex){
            id action = [actions objectAtIndex:buttonIndex];
            switch ([[action objectForKey:@"type"] integerValue]) {
                case kActionTypeGenChildKey:
                {
                    [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
                        if (unlocked) {
                            [self onActionClickedGenChildKey:blind_account section:section];
                        }
                    }];
                }
                    break;
                case kActionTypeCopyKey:
                    [self onActionClickedCopyKey:blind_account];
                    break;
                default:
                    assert(false);
                    break;
            }
        }
    }];
}

- (void)onActionClickedGenChildKey:(id)blind_account section:(NSInteger)section
{
    //  TODO:6.0 限制子账号数量，比如3个或5个。（扫描恢复收据验证to等时候容易一些。）
    
    assert(blind_account);
    //  TODO:6.0
    NSString* main_public_key = [blind_account objectForKey:@"public_key"];
    assert(main_public_key);
    
    WalletManager* walletMgr = [WalletManager sharedWalletManager];
    GraphenePrivateKey* main_pri_key = [walletMgr getGraphenePrivateKeyByPublicKey:main_public_key];
    if (!main_pri_key) {
        [OrgUtils makeToast:@"主账号私钥不存在，请重新导入。"];
        return;
    }
    
    secp256k1_prikey* pri_keydata = [main_pri_key getKeyData];
    
    //  开始创建子KEY
    HDWallet* hdk = [HDWallet fromMasterSeed:[[NSData alloc] initWithBytes:pri_keydata->data length:sizeof(pri_keydata->data)]];
    
    //  计算新子账号索引（子账号已经根据索引升序排列了，直接区最后一个即可。）
    id section_item = [_dataArray objectAtIndex:section];
    NSInteger new_child_key_index = 0;
    id data_child_array = [section_item objectForKey:@"child"];
    if (data_child_array && [data_child_array count] > 0) {
        new_child_key_index = [[[data_child_array lastObject] objectForKey:@"child_key_index"] integerValue] + 1;
    }
    
    HDWallet* child_key = [hdk deriveBitsharesStealthChildKey:new_child_key_index];
    id wif_child_pri_key = [child_key toWifPrivateKey];
    id wif_child_pub_key = [OrgUtils genBtsAddressFromWifPrivateKey:wif_child_pri_key];
    
    id child_blind_account = @{
        @"public_key": wif_child_pub_key,
        @"alias_name": @"",
        @"parent_key": main_public_key,
        @"child_key_index": @(new_child_key_index)
    };
    
    //  隐私交易子地址导入钱包
    AppCacheManager* pAppCache = [AppCacheManager sharedAppCacheManager];
    
    id full_wallet_bin = [walletMgr walletBinImportAccount:nil privateKeyWifList:@[wif_child_pri_key]];
    assert(full_wallet_bin);
    [pAppCache appendBlindAccount:child_blind_account autosave:NO];
    [pAppCache updateWalletBin:full_wallet_bin];
    [pAppCache autoBackupWalletToWebdir:NO];
    
    //  重新解锁（即刷新解锁后的账号信息）。
    id unlockInfos = [walletMgr reUnlock];
    assert(unlockInfos && [[unlockInfos objectForKey:@"unlockSuccess"] boolValue]);
    
    //  导入成功
    [self refreshUI:YES];
    [OrgUtils makeToast:@"创建子账户成功。"];
}

- (void)onActionClickedCopyKey:(id)blind_account
{
    assert(blind_account);
    [UIPasteboard generalPasteboard].string = [[blind_account objectForKey:@"public_key"] copy];
    [OrgUtils makeToast:NSLocalizedString(@"kVcDWTipsCopyOK", @"已复制")];
}

@end
