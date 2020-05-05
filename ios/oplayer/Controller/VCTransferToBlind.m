//
//  VCTransferToBlind.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCTransferToBlind.h"
#import "VCStealthTransferHelper.h"
#import "ViewBlindInputOutputItemCell.h"

#import "VCBlindBackupReceipt.h"
#import "VCSearchNetwork.h"
#import "VCBlindOutputAddOne.h"
#import "ViewTipsInfoCell.h"
#import "ViewEmptyInfoCell.h"

enum
{
    kVcSecOpAsst = 0,       //  要操作的资产
    kVcSecBlindOutput,      //  隐私输出
    kVcSecAddOne,           //  新增按钮
    kVcSecBalance,          //  转账总数量、可用数量、广播手续费
    kVcSecSubmit,           //  提交按钮
    kVcSecTips,             //  提示信息
    
    kvcSecMax
};

enum
{
    kVcSubAvailbleBalance = 0,
    kVcSubNetworkFee,
    kVcSubOutputTotalAmount,
    
    kVcSubMax
};

@interface VCTransferToBlind ()
{
    NSDictionary*               _curr_asset;            //  当前资产
    NSDictionary*               _full_account_data;
    NSDecimalNumber*            _nCurrBalance;
    NSDecimalNumber*            _nFee;
    
    UITableViewBase*            _mainTableView;
    
    ViewTipsInfoCell*           _cell_tips;
    ViewEmptyInfoCell*          _cell_add_one;
    ViewBlockLabel*             _lbCommit;
    
    NSMutableArray*             _data_array_blind_output;
}

@end

@implementation VCTransferToBlind

-(void)dealloc
{
    _nCurrBalance = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _cell_tips = nil;
    _cell_add_one = nil;
    _lbCommit = nil;
}

- (id)initWithCurrAsset:(id)curr_asset
      full_account_data:(id)full_account_data
{
    self = [super init];
    if (self) {
        assert(curr_asset);
        assert([ModelUtils assetAllowConfidential:curr_asset]);
        assert(![ModelUtils assetIsTransferRestricted:curr_asset]);
        assert(![ModelUtils assetNeedWhiteList:curr_asset]);
        assert(full_account_data);
        _curr_asset = curr_asset;
        _full_account_data = full_account_data;
        _data_array_blind_output = [NSMutableArray array];
        _nFee = [self calcNetworkFee];
        _nCurrBalance = [ModelUtils findAssetBalance:_full_account_data asset:_curr_asset];
    }
    return self;
}

- (NSDecimalNumber*)calcNetworkFee
{
    return [[ChainObjectManager sharedChainObjectManager] getNetworkCurrentFee:ebo_transfer_to_blind
                                                                         kbyte:nil
                                                                           day:nil
                                                                        output:(NSDecimalNumber*)[NSDecimalNumber numberWithUnsignedInteger:[_data_array_blind_output count]]];
}

- (void)refreshView
{
    [_mainTableView reloadData];
}

- (NSString*)genTransferTipsMessage
{
    //  TODO:6.0 lang
    return @"【温馨提示】\n隐私转账可同时指定多个隐私地址。";
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    self.view.backgroundColor = theme.appBackColor;
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 提示信息
    _cell_tips = [[ViewTipsInfoCell alloc] initWithText:[self genTransferTipsMessage]];
    _cell_tips.hideBottomLine = YES;
    _cell_tips.hideTopLine = YES;
    _cell_tips.backgroundColor = [UIColor clearColor];
    
    //  TODO:6.0 lang
    _cell_add_one = [[ViewEmptyInfoCell alloc] initWithText:@"添加输出" iconName:@"iconAdd"];
    _cell_add_one.showCustomBottomLine = YES;
    _cell_add_one.accessoryType = UITableViewCellAccessoryNone;
    _cell_add_one.selectionStyle = UITableViewCellSelectionStyleBlue;
    _cell_add_one.userInteractionEnabled = YES;
    _cell_add_one.imgIcon.tintColor = theme.textColorHighlight;
    _cell_add_one.lbText.textColor = theme.textColorHighlight;
    
    _lbCommit = [self createCellLableButton:@"隐私转入"];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kvcSecMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case kVcSecOpAsst:
            return 2;
        case kVcSecBlindOutput:
            //  title + all blind output
            return 1 + [_data_array_blind_output count];
        case kVcSecBalance:
            return kVcSubMax;
        default:
            break;
    }
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcSecOpAsst:
            if (indexPath.row == 0) {
                return 28.0f;
            }
            break;
        case kVcSecBlindOutput:
        {
            if (indexPath.row == 0) {
                return 28.0f;   //  title
            } else {
                return 32.0f;
            }
        }
            break;
        case kVcSecBalance:
            return 28.0f;       //  TODO:6.0
        case kVcSecTips:
            return [_cell_tips calcCellDynamicHeight:tableView.layoutMargins.left];
        default:
            break;
    }
    return tableView.rowHeight;
}

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case kVcSecAddOne:
            return 0.01f;
        case kVcSecBalance:
            return 0.01f;
        default:
            break;
    }
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
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    switch (indexPath.section) {
        case kVcSecOpAsst:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.textColor = theme.textColorMain;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (indexPath.row == 0) {
                cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                cell.textLabel.text = NSLocalizedString(@"kOtcMcAssetTransferCellLabelAsset", @"资产");
                cell.hideBottomLine = YES;
            } else {
                cell.showCustomBottomLine = YES;
                cell.textLabel.text = [_curr_asset objectForKey:@"symbol"];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.textLabel.textColor = theme.textColorMain;
            }
            return cell;
        }
            break;
        case kVcSecBlindOutput:
        {
            static NSString* identify = @"id_blind_output_info";
            ViewBlindInputOutputItemCell* cell = (ViewBlindInputOutputItemCell*)[tableView dequeueReusableCellWithIdentifier:identify];
            if (!cell)
            {
                cell = [[ViewBlindInputOutputItemCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                           reuseIdentifier:identify
                                                                        vc:self
                                                                    action:@selector(onButtonClicked_OutputRemove:)];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
            cell.showCustomBottomLine = NO;
            cell.itemType = kBlindItemTypeOutput;
            [cell setTagData:indexPath.row];
            if (indexPath.row == 0) {
                [cell setItem:@{@"title":@YES, @"num":@([_data_array_blind_output count])}];
            } else {
                [cell setItem:[_data_array_blind_output objectAtIndex:indexPath.row - 1]];
            }
            return cell;
        }
            break;
        case kVcSecBalance:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.textColor = theme.textColorGray;
            cell.detailTextLabel.textColor = theme.textColorNormal;
            cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0f];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.hideTopLine = YES;
            cell.hideBottomLine = YES;
            
            id symbol = _curr_asset[@"symbol"];
            
            switch (indexPath.row) {
                case kVcSubAvailbleBalance:
                {
                    NSDecimalNumber* n_total = [self calcBlindOutputTotalAmount];
                    cell.textLabel.text = @"可用余额";
                    id base_str = [NSString stringWithFormat:@"%@ %@",
                                   [OrgUtils formatFloatValue:_nCurrBalance usesGroupingSeparator:NO],
                                   symbol];
                    if ([_nCurrBalance compare:n_total] < 0) {
                        cell.detailTextLabel.textColor = theme.tintColor;
                        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@(%@)",
                                                     base_str,
                                                     NSLocalizedString(@"kVcTradeTipAmountNotEnough", @"数量不足")];//TODO:6.0 lang
                    } else {
                        cell.detailTextLabel.textColor = theme.textColorNormal;
                        cell.detailTextLabel.text = base_str;
                    }
                }
                    break;
                case kVcSubOutputTotalAmount:
                    cell.textLabel.text = @"输出总金额";
                    cell.detailTextLabel.textColor = theme.buyColor;
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:[self calcBlindOutputTotalAmount] usesGroupingSeparator:NO], symbol];
                    break;
                case kVcSubNetworkFee:
                {
                    cell.textLabel.text = @"广播手续费";
                    if (_nFee) {
                        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:_nFee usesGroupingSeparator:NO], [ChainObjectManager sharedChainObjectManager].grapheneCoreAssetSymbol];
                    } else {
                        cell.detailTextLabel.text = @"未知";
                    }
                }
                    break;
                default:
                    break;
            }
            return cell;
        }
            break;
            
        case kVcSecTips:
            return _cell_tips;
            
        case kVcSecAddOne:
            return _cell_add_one;
            
        case kVcSecSubmit:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_lbCommit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        default:
            break;
    }
    //  not reached.
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        switch (indexPath.section) {
            case kVcSecOpAsst:
                [self onSelectAssetClicked];
                break;
            case kVcSecAddOne:
                [self onAddOneClicked];
                break;
            case kVcSecSubmit:
                [self onSubmitClicked];
                break;
            default:
                break;
        }
    }];
}

- (void)onSelectAssetClicked
{
    VCSearchNetwork* vc = [[VCSearchNetwork alloc] initWithSearchType:enstAssetAll callback:^(id asset_info) {
        if (asset_info){
            if (![ModelUtils assetAllowConfidential:asset_info]) {
                //  TODO:6.0 lang
                [OrgUtils makeToast:[NSString stringWithFormat:@"资产 %@ 已禁止隐私转账。", asset_info[@"symbol"]]];
            } else if ([ModelUtils assetIsTransferRestricted:asset_info]) {
                //  TODO:6.0 lang
                [OrgUtils makeToast:[NSString stringWithFormat:@"资产 %@ 禁止转账。", asset_info[@"symbol"]]];
            } else if ([ModelUtils assetNeedWhiteList:asset_info]) {
                //  TODO:6.0 lang
                [OrgUtils makeToast:[NSString stringWithFormat:@"资产 %@ 已开启白名单，禁止隐私转账。", asset_info[@"symbol"]]];
            } else {
                NSString* new_id = [asset_info objectForKey:@"id"];
                NSString* old_id = [_curr_asset objectForKey:@"id"];
                if (![new_id isEqualToString:old_id]) {
                    _curr_asset = asset_info;
                    //  切换资产：更新余额、清空当前收款人、更新手续费
                    _nCurrBalance = [ModelUtils findAssetBalance:_full_account_data asset:_curr_asset];
                    [_data_array_blind_output removeAllObjects];
                    [self onBlindOutputChanged];
                    [_mainTableView reloadData];
                }
            }
        }
    }];
    
    [self pushViewController:vc
                     vctitle:NSLocalizedString(@"kVcTitleSearchAssets", @"搜索资产")
                   backtitle:kVcDefaultBackTitleName];
}

/**
 *  事件 - 移除某个隐私输出
 */
- (void)onButtonClicked_OutputRemove:(UIButton*)button
{
    [_data_array_blind_output removeObjectAtIndex:button.tag - 1];
    [self onBlindOutputChanged];
    //  刷新UI
    [_mainTableView reloadData];
}

- (void)onBlindOutputChanged
{
    //  输出数量变更重新计算手续费
    _nFee = [self calcNetworkFee];
}

- (void)onAddOneClicked
{
    //  可配置：限制最大隐私输出数量
    int allow_maximum_blind_output = 5;
    if ([_data_array_blind_output count] >= allow_maximum_blind_output) {
        //  TODO:6.0 lang
        [OrgUtils makeToast:[NSString stringWithFormat:@"最多只能添加 %@ 个隐私输出。", @(allow_maximum_blind_output)]];
        return;
    }
    
    //  REMARK：在主线程调用，否则VC弹出可能存在卡顿缓慢的情况。
    [self delay:^{
        //  转到添加权限界面
        WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
        VCBlindOutputAddOne* vc = [[VCBlindOutputAddOne alloc] initWithResultPromise:result_promise asset:_curr_asset];
        [self pushViewController:vc
                         vctitle:@"新增隐私输出"//TODO:6.0 lang
                       backtitle:kVcDefaultBackTitleName];
        [result_promise then:(^id(id json_data) {
            assert(json_data);
            //  添加
            [_data_array_blind_output addObject:json_data];
            [self onBlindOutputChanged];
            //  刷新
            [_mainTableView reloadData];
            return nil;
        })];
    }];
}

- (NSDecimalNumber*)calcBlindOutputTotalAmount
{
    NSDecimalNumber* n_total = [NSDecimalNumber zero];
    for (id item in _data_array_blind_output) {
        n_total = [n_total decimalNumberByAdding:[item objectForKey:@"n_amount"]];
    }
    return n_total;
}

- (void)onSubmitClicked
{
    //    //  TODO:6.0 test ui
    //    VCBlindBackupReceipt* vc = [[VCBlindBackupReceipt alloc] initWithTrxResult:@[@{@"block_num":@3, @"id":@"abcd"}]];
    //    [self clearPushViewController:vc vctitle:@"备份收据" backtitle:kVcDefaultBackTitleName];
    //    return;
    
    //    HDWallet* hdk = [HDWallet fromMnemonic:@"A"];
    //    HDWallet* new_key = [hdk deriveBitsharesStealthChildKey:1];
    //    id new_pri = [new_key toWifPrivateKey];
    //    id new_pri_p = [OrgUtils genBtsAddressFromWifPrivateKey:new_pri];
    //
    //    HDWallet* new_key2 = [hdk deriveBitsharesStealthChildKey:0];
    //    id new_pri2 = [new_key2 toWifPrivateKey];
    //    id new_pri_p2 = [OrgUtils genBtsAddressFromWifPrivateKey:new_pri2];
    //
    //    NSLog(@"");
    //    return;
    
    //  TODO:6.0 DEBUG 临时清空
    //    AppCacheManager* pAppCahce = [AppCacheManager sharedAppCacheManager];
    //    for (id vi in [[pAppCahce getAllBlindBalance] allValues]) {
    //        [pAppCahce removeBlindBalance:vi];
    //    }
    //    [pAppCahce saveStealthReceiptToFile];
    //    return;
    
    NSInteger i_output_count = [_data_array_blind_output count];
    if (i_output_count <= 0) {
        [OrgUtils makeToast:@"请添加隐私输出地址和数量。"];
        return;
    }
    
    //  TODO:6.0 asset
    //    id asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:@"1.3.0"];
    
    NSDecimalNumber* n_total = [self calcBlindOutputTotalAmount];
    if ([n_total compare:[NSDecimalNumber zero]] <= 0) {
        [OrgUtils makeToast:@"输出金额不能为空。"];
        return;
    }
    
    //  TODO:6.0 余额判断 >0 < max_balance
    if ([_nCurrBalance compare:n_total] < 0) {
        [OrgUtils makeToast:@"余额不足。"];
        return;
    }
    
    //  生成隐私输出
    id blind_output_args = [VCStealthTransferHelper genBlindOutputs:_data_array_blind_output
                                                              asset:_curr_asset
                                             input_blinding_factors:nil];
    //  生成所有隐私输出承诺盲因子之和。
    id receipt_array = [blind_output_args objectForKey:@"receipt_array"];
    id blinding_factor = [VCStealthTransferHelper blindSum:[receipt_array ruby_map:^id(id src) {
        return [src objectForKey:@"blind_factor"];
    }]];
    
    //  构造OP
    id s_total = [NSString stringWithFormat:@"%@", [n_total decimalNumberByMultiplyingByPowerOf10:[_curr_asset[@"precision"] integerValue]]];
    id op_account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    id op = @{
        @"fee":@{@"asset_id":[ChainObjectManager sharedChainObjectManager].grapheneCoreAssetID, @"amount":@0},
        @"amount":@{@"asset_id":_curr_asset[@"id"], @"amount":@([s_total unsignedLongLongValue])},
        @"from":op_account[@"id"],
        @"blinding_factor":blinding_factor,
        @"outputs":blind_output_args[@"blind_outputs"]
    };
    
    NSString* value;
    if (i_output_count > 1) {
        value = [NSString stringWithFormat:@"您确定往 %@ 个隐私账户合计转入 %@ %@ 吗？",
                 @(i_output_count),
                 n_total,
                 _curr_asset[@"symbol"]];
    } else {
        value = [NSString stringWithFormat:@"您确定往隐私账户转入 %@ %@ 吗？",
                 n_total,
                 _curr_asset[@"symbol"]];
    }
    [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:value
                                                           withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                          completion:^(NSInteger buttonIndex)
     {
        if (buttonIndex == 1)
        {
            [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
                if (unlocked) {
                    
                    //  TODO:6.0 支持提案...
                    
                    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
                    [[[[BitsharesClientManager sharedBitsharesClientManager] transferToBlind:op] then:^id(id tx_data) {
                        [self hideBlockView];
                        
                        //  自动导入【我的】收据
                        WalletManager* walletMgr = [WalletManager sharedWalletManager];
                        AppCacheManager* pAppCahce = [AppCacheManager sharedAppCacheManager];
                        for (id item in receipt_array) {
                            id blind_balance = [item objectForKey:@"blind_balance"];
                            assert(blind_balance);
                            //  REMARK：有隐私账号私钥的收据即为我自己的收据。
                            id real_to_key = [blind_balance objectForKey:@"real_to_key"];
                            if (real_to_key && [walletMgr havePrivateKey:real_to_key]) {
                                [pAppCahce appendBlindBalance:blind_balance];
                            }
                        }
                        [pAppCahce saveWalletInfoToFile];
                        
                        //  统计
                        [OrgUtils logEvents:@"txTransferToBlindFullOK" params:@{@"asset":_curr_asset[@"symbol"]}];
                        
                        //  转到备份收据界面 TODO:6.0 lang
                        VCBlindBackupReceipt* vc = [[VCBlindBackupReceipt alloc] initWithTrxResult:tx_data];
                        [self clearPushViewController:vc vctitle:@"备份收据" backtitle:kVcDefaultBackTitleName];
                        return nil;
                    }] catch:^id(id error) {
                        [self hideBlockView];
                        NSLog(@"%@", error);
                        [OrgUtils showGrapheneError:error];
                        return nil;
                    }];
                }
            }];
        }
    }];
}

@end