//
//  HJYMainViewController.m
//  FindOADVersion
//
//  Created by LunaticMe on 14-7-19.
//  Copyright (c) 2014年 JinyouHu. All rights reserved.
//

#import "HJYMainViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "HJYBLE.h"
#import "oad.h"
#import "HJYProgressViewController.h"

#define OAD_SERVICE_UUID                @"0xF000FFC0-0451-4000-B000-000000000000"   //OAD Service UUID
#define OAD_IMAGE_NOTIFY_UUID           @"0xF000FFC1-0451-4000-B000-000000000000"   //OAD Image Notify UUID
#define OAD_IMAGE_BLOCK_REQUEST_UUID    @"0xF000FFC2-0451-4000-B000-000000000000"   //AD Image Block Request UUID

@interface HJYMainViewController ()<CBCentralManagerDelegate , CBPeripheralDelegate, UIActionSheetDelegate, UITableViewDataSource, UITableViewDelegate>

@property (retain, nonatomic) CBCentralManager *centralManager;

@property (retain, nonatomic) CBPeripheral *peripheral;

- (IBAction)scan:(id)sender;

@property (weak, nonatomic) IBOutlet UITableView *peripheralTable;

- (IBAction)selectedFirmWare:(id)sender;

@property (retain, nonatomic) NSMutableArray *peripheralArr;

@property (retain, nonatomic) NSTimer *imageDetectTimer;

@property (assign, nonatomic) uint16_t imgVersion;

@property (assign, nonatomic) BOOL start;

- (IBAction)clearPerapheral:(id)sender;

@property (assign, nonatomic) BOOL inProgramming;

@property (weak, nonatomic) IBOutlet UIButton *selectedFirmWareButton;

@property (retain, nonatomic) NSData *imageFile;

@property (assign, nonatomic) BOOL cancled;

@property (assign ,nonatomic) int nBlocks ;

@property (assign, nonatomic) int nBytes;

@property (assign, nonatomic) int iBlocks;

@property (assign, nonatomic) int iBytes;

@property (retain, nonatomic) HJYProgressViewController *progressViewController;

@end

@implementation HJYMainViewController

@synthesize peripheralArr = _peripheralArr;

@synthesize imageDetectTimer = _imageDetectTimer;

@synthesize imgVersion = _imgVersion;

@synthesize start = _start;

@synthesize inProgramming = _inProgramming;

@synthesize imageFile = _imageFile;

@synthesize cancled = _cancled;

@synthesize nBlocks = _nBlocks;

@synthesize nBytes = _nBytes;

@synthesize iBlocks = _iBlocks;

@synthesize iBytes = _iBytes;

@synthesize progressViewController = _progressViewController;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

/**
 *  using
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    self.imgVersion = 0xFFFF;
    self.start = YES;
    
    self.peripheralArr = [[NSMutableArray alloc] init];
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    self.peripheralTable.delegate = self;
    self.peripheralTable.dataSource = self;
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/**
 *  using
 */
- (IBAction)scan:(id)sender
{
    [self.peripheralArr removeAllObjects];
    
    if (self.peripheral)
    {
        [self.centralManager cancelPeripheralConnection:self.peripheral];
    }
    
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
    [self.peripheralTable reloadData];
}


- (IBAction)selectedFirmWare:(id)sender
{
    
    [self configureProfile];
    
    NSMutableArray *a = [[NSMutableArray alloc] initWithArray:[NSArray array]];
    
    UIActionSheet *act = [[UIActionSheet alloc] initWithTitle:@"select firmware" delegate:self cancelButtonTitle:@"Cancle" destructiveButtonTitle:nil otherButtonTitles:@"AThermometer", @"BThermometer", nil];
    [act showInView:self.view];
}

/**
 *  using
 */
-(void)validateImage
{
    if ([self isCorrectImage])
    {
        [self uploadImage];
    }
    else {
        UIAlertView *wrongImage = [[UIAlertView alloc]initWithTitle:@"Wrong image type !" message:[NSString stringWithFormat:@"Image that was selected was of type : %c, which is the same as on the peripheral, please select another image",(self.imgVersion & 0x01) ? 'B' : 'A'] delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles: nil];
        [wrongImage show];
    }
}

/**
 *  using
 */
-(BOOL) isCorrectImage
{
    unsigned char imageFileData[self.imageFile.length];
    [self.imageFile getBytes:imageFileData];
    
    img_hdr_t imgHeader;
    memcpy(&imgHeader, &imageFileData[0 + OAD_IMG_HDR_OSET], sizeof(img_hdr_t));
        //    memcpy(<#dest#>, <#src#>, <#len#>)
    
    if ((imgHeader.ver & 0x01) != (self.imgVersion & 0x01))
        return YES;
    return NO;
}

/**
 *  using
 */
- (IBAction)clearPerapheral:(id)sender
{
    [self.peripheralArr removeAllObjects];
    
    [self.peripheralTable reloadData];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)msg
{
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:title message:msg delegate:self cancelButtonTitle:@"cancle" otherButtonTitles:nil, nil];
    [av show];
}


/**
 *  using
 */
-(void) configureProfile {
    NSLog(@"Configurating OAD Profile");
    CBUUID *sUUID = [CBUUID UUIDWithString:OAD_SERVICE_UUID];
    CBUUID *cUUID = [CBUUID UUIDWithString:OAD_IMAGE_NOTIFY_UUID];
    [HJYBLE setNotificationForCharacteristic:self.peripheral sCBUUID:sUUID cCBUUID:cUUID enable:YES];
    unsigned char data = 0x00;
    [HJYBLE writeCharacteristic:self.peripheral sCBUUID:sUUID cCBUUID:cUUID data:[NSData dataWithBytes:&data length:1]];
    self.imageDetectTimer = [NSTimer scheduledTimerWithTimeInterval:1.5f target:self selector:@selector(imageDetectTimerTick:) userInfo:nil repeats:NO];
    self.imgVersion = 0xFFFF;
    self.start = YES;
}

-(void) imageDetectTimerTick:(NSTimer *)timer {
        //IF we have come here, the image userID is B.
    NSLog(@"imageDetectTimerTick:");
    CBUUID *sUUID = [CBUUID UUIDWithString:OAD_SERVICE_UUID];
    CBUUID *cUUID = [CBUUID UUIDWithString:OAD_IMAGE_NOTIFY_UUID];
    unsigned char data = 0x01;
    [HJYBLE writeCharacteristic:self.peripheral sCBUUID:sUUID cCBUUID:cUUID data:[NSData dataWithBytes:&data length:1]];
}

-(void)deviceDisconnected:(CBPeripheral *)peripheral
{
    if ([peripheral isEqual:self.peripheral] && self.inProgramming) {
        NSLog(@"dismiss progress view . ");
        UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:@"FW Upgrade Failed !" message:@"Device disconnected during programming, firmware upgrade was not finished !" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        alertView.tag = 0;
        [alertView show];
        self.inProgramming = NO;
    }
}

-(void) didUpdateValueForProfile:(CBCharacteristic *)characteristic {
    NSLog(@"didUpdateValueForProfile   %@",characteristic);
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:OAD_IMAGE_NOTIFY_UUID]]) {
        NSLog(@"%@",characteristic.value);
        if (self.imgVersion == 0xFFFF) {
            unsigned char data[characteristic.value.length];
            [characteristic.value getBytes:&data];
            self.imgVersion = ((uint16_t)data[1] << 8 & 0xff00) | ((uint16_t)data[0] & 0xff);
            NSLog(@"self.imgVersion : %04hx",self.imgVersion);
        }
        NSLog(@"OAD Image notify : %@",characteristic.value);
        
    }
}

#pragma mark - actionsheet delegate

/**
 *  using for selected firmware
 */
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSArray *imgArr = @[@"Athermometer.bin",@"Bthermometer.bin"];
    if (buttonIndex < 2) {
        NSLog(@"Loaded firmware \"%@\"of size : %d",imgArr[buttonIndex],(int)self.imageFile.length);
        self.imageFile = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:imgArr[buttonIndex] ofType:nil]];
        [self validateImage];
    }
    
}



#pragma mark - central manager delegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (!(self.centralManager.state == CBCentralManagerStatePoweredOn)) {
        [self showAlertWithTitle:@"warning" message:@"your device don't valid BLE 4.0"];
    }
    [self.centralManager scanForPeripheralsWithServices:nil options:nil];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    if (![self.peripheralArr containsObject:peripheral]) {
        [self.peripheralArr addObject:peripheral];
    }
    [self.peripheralTable reloadData];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    [self.peripheral discoverServices:nil];
    
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    [self deviceDisconnected:peripheral];
    [self showAlertWithTitle:@"warning" message:@"cann't connect to thermometer peripheral"];
}

#pragma mark - peripheral delegate

/**
 *  using
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

/**
 *  using
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NSLog(@"service : %@",service.UUID);
    if ([service.UUID isEqual:[CBUUID UUIDWithString:OAD_SERVICE_UUID]]) {
        self.selectedFirmWareButton.enabled = YES;
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    [self didUpdateValueForProfile:characteristic];
}


/**
 *  using
 */
#pragma mark - table view delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.peripheralArr.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *STRID = @"STRID";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:STRID];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:STRID];
    }
    
    CBPeripheral *peripheral = [self.peripheralArr objectAtIndex:indexPath.row];
    cell.textLabel.text = peripheral.name;
    cell.detailTextLabel.text = [peripheral.identifier UUIDString];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    self.peripheral = [self.peripheralArr objectAtIndex:indexPath.row];
    self.peripheral.delegate = self;
    if (!(self.peripheral.state == CBPeripheralStateConnected)) {
        [self.centralManager connectPeripheral:self.peripheral options:nil];
    }
}





/**
 *  ///////////////////////////////////
 */

- (void)uploadImage
{
    self.inProgramming = YES;
    self.cancled = NO;
    
    unsigned char imageFileData[self.imageFile.length];
    [self.imageFile getBytes:imageFileData];
    uint8_t requestData[OAD_IMG_HDR_SIZE + 2 + 2];  //12 bytes
    
    for (int i=0; i<20; i++) {
        NSLog(@"%02hhx",imageFileData[i]);
    }
    
    img_hdr_t imgHeader;
    memcpy(&imgHeader, &imageFileData[0 + OAD_IMG_HDR_OSET], sizeof(img_hdr_t));
    
    requestData[0] = LO_UINT16(imgHeader.ver);
    requestData[1] = HI_UINT16(imgHeader.ver);
    
    requestData[2] = LO_UINT16(imgHeader.len);
    requestData[3] = HI_UINT16(imgHeader.len);
    
    requestData[OAD_IMG_HDR_SIZE + 0] = LO_UINT16(12);
    requestData[OAD_IMG_HDR_SIZE + 1] = HI_UINT16(12);
    
    requestData[OAD_IMG_HDR_SIZE + 2] = LO_UINT16(15);
    requestData[OAD_IMG_HDR_SIZE + 1] = HI_UINT16(15);
    
    CBUUID *sUUID = [CBUUID UUIDWithString:OAD_SERVICE_UUID];
    CBUUID *cUUID = [CBUUID UUIDWithString:OAD_IMAGE_NOTIFY_UUID];
    
    [HJYBLE writeCharacteristic:self.peripheral sCBUUID:sUUID cCBUUID:cUUID data:[NSData dataWithBytes:requestData length:(OAD_IMG_HDR_SIZE + 2 +2)]];
    
    self.nBlocks = imgHeader.len / (OAD_BLOCK_SIZE / HAL_FLASH_WORD_SIZE);
    self.nBytes = imgHeader.len * HAL_FLASH_WORD_SIZE;
    
    self.iBlocks = 0;
    self.iBytes = 0;
    
    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(programmingTimerTick:) userInfo:nil repeats:NO];
    
}

- (void)programmingTimerTick:(NSTimer *)timer
{
    if (self.cancled) {
        self.cancled = FALSE;
        return;
    }
    
    unsigned char imageFileData[self.imageFile.length];
    [self.imageFile getBytes:imageFileData];
    
    uint8_t requestData[2 + OAD_BLOCK_SIZE];
    
        // This block is run 4 times, this is needed to get CoreBluetooth to send consequetive packets in the same connection interval.
    for (int i=0; i<4; i++) {
        requestData[0] = LO_UINT16(self.iBlocks);
        requestData[1] = HI_UINT16(self.iBlocks);
        
        memcpy(&requestData[2], &imageFileData[self.iBytes], OAD_BLOCK_SIZE);
        
        CBUUID *sUUID = [CBUUID UUIDWithString:OAD_SERVICE_UUID];
        CBUUID *cUUID = [CBUUID UUIDWithString:OAD_IMAGE_BLOCK_REQUEST_UUID];
        
        [HJYBLE writeNoResponseCharacteristic:self.peripheral sCBUUID:sUUID cCBUUID:cUUID data:[NSData dataWithBytes:requestData length:(2 + OAD_BLOCK_SIZE)]];
        
        self.iBlocks ++;
        self.iBytes += OAD_BLOCK_SIZE;
        
            //        NSLog(@"iBlocks %d  iBytes %d : %@",self.iBlocks, self.iBytes,[NSData dataWithBytes:requestData length:(2 + OAD_BLOCK_SIZE)]);
        
        if (self.iBlocks == self.nBlocks) {
            
            self.inProgramming = NO;
            
            [self completionDialog];
            
            return;
        }
        else
        {
            if (i == 3) {
                [NSTimer scheduledTimerWithTimeInterval:0.09 target:self selector:@selector(programmingTimerTick:) userInfo:nil repeats:NO];
            }
        }
        
    }
    
    float pro = (float)((float)self.iBlocks / (float)self.nBlocks);
    
    self.progressViewController.progressBar.progress = pro;
    self.progressViewController.progressLabel.text = [NSString stringWithFormat:@"%0.1f%%",pro * 100.0f];
    
    float secondsPerBlock = 0.09 / 4;
    float secondsLeft = (float)(self.nBlocks - self.iBlocks) * secondsPerBlock;
    
    self.progressViewController.progressBar.progress = pro;
    self.progressViewController.progressLabel.text = [NSString stringWithFormat:@"%0.1f%%",pro * 100.0f];
    self.progressViewController.timeLabel.text = [NSString stringWithFormat:@"Time remaining : %d:%02d",(int)(secondsLeft / 60), (int)secondsLeft - (int)(secondsLeft / 60) * (int)60];
    
    if (self.start) {
        self.start = NO;
        if (!self.progressViewController) {
            self.progressViewController = [[HJYProgressViewController alloc] init];
        }
        [self presentViewController:self.progressViewController animated:YES completion:^{}];
    }
    
}

-(void) completionDialog {
    UIAlertView *complete;
    complete = [[UIAlertView alloc]initWithTitle:@"Firmware upgrade complete" message:@"Firmware upgrade was successfully completed, device needs to be reconnected" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [complete show];
    [self.progressViewController dismissViewControllerAnimated:YES completion:nil];
    self.start = YES;
    [self.selectedFirmWareButton setTitle:[NSString stringWithFormat:@"Written (cur is %c)",(self.imgVersion & 0x01) ? 'B' : 'A'] forState:UIControlStateNormal];
}
































@end
