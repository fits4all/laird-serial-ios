//
//  UARTPeripheral.m
//  nRF UART
//
//  Created by Ole Morten on 1/12/13.
//  Copyright (c) 2013 Nordic Semiconductor. All rights reserved.
//

#import "UARTPeripheral.h"

static UI16 MscPubHexCharToNibble(CHAR ch);
static int StdISXDIGIT(UI8 ch);
static EMscStringParseState MscPubDeEscapeString(
    FProcDeEscaped fProcDeEscaped,
    VOID *pContext,
    EMscStringParseState eState,
    UI8  *pSrc,
    UI16 *pByteCount    /* on entry length of pSrc, exit len of deescaped string */
);

static UWRESULTCODE    /* will be SUCCESS if no errors */
MscPubDeEscape(
    const char  *pSrc,
    UI16  nSrcLen,
    UI8  *pDst,
    UI16 *pDstLen   /* on entry, dest buf len, on exit len of deescaped string */
);

@interface UARTPeripheral ()

@property CBService *uartService;
@property CBCharacteristic *rxCharacteristic;
@property CBCharacteristic *txCharacteristic;
@property CBCharacteristic *modemInCharacteristic;
@property CBCharacteristic *modemOutCharacteristic;
@property uint8_t   modemInValue;
@property uint8_t   modemOutValue;

@property NSLock    *sendLocker;
@end

@implementation UARTPeripheral
@synthesize peripheral = _peripheral;
@synthesize delegate = _delegate;

@synthesize uartService = _uartService;
@synthesize rxCharacteristic = _rxCharacteristic;
@synthesize txCharacteristic = _txCharacteristic;
@synthesize modemInValue = _modemInValue;
@synthesize modemOutValue = _modemOutValue;

@synthesize serialRequest = _serialRequest;
@synthesize sendBuffer = _sendBuffer;
@synthesize errorCount = _errorCount;
@synthesize sendLength = _sendLength;
@synthesize maxSendLength = _maxSendLength;
@synthesize serialError = _serialError;

+ (CBUUID *) uartServiceUUID
{
  //return [CBUUID UUIDWithString:@"6e400001-b5a3-f393-e0a9-e50e24dcca9e"];
    return [CBUUID UUIDWithString:@"569a1101-b87f-490c-92cb-11ba5ea5167c"];
}

+ (CBUUID *) txCharacteristicUUID   //data going to the module
{
    //return [CBUUID UUIDWithString:@"6e400002-b5a3-f393-e0a9-e50e24dcca9e"];
    return [CBUUID UUIDWithString:@"569a2001-b87f-490c-92cb-11ba5ea5167c"];
}
+ (CBUUID *) rxCharacteristicUUID  //data coming from the module
{
    //return [CBUUID UUIDWithString:@"6e400003-b5a3-f393-e0a9-e50e24dcca9e"];
    return [CBUUID UUIDWithString:@"569a2000-b87f-490c-92cb-11ba5ea5167c"];
}
+ (CBUUID *) modemInCharacteristicUUID
{
    return [CBUUID UUIDWithString:@"569a2003-b87f-490c-92cb-11ba5ea5167c"];
}
+ (CBUUID *) modemOutCharacteristicUUID
{
    return [CBUUID UUIDWithString:@"569a2002-b87f-490c-92cb-11ba5ea5167c"];
}

+ (CBUUID *) deviceInformationServiceUUID
{
    return [CBUUID UUIDWithString:@"180A"];
}

+ (CBUUID *) hardwareRevisionStringUUID
{
    return [CBUUID UUIDWithString:@"2A27"];
}

- (UARTPeripheral *) initWithPeripheral:(CBPeripheral*)peripheral delegate:(id<UARTPeripheralDelegate>) delegate
{
    if (self = [super init])
    {
        _peripheral = peripheral;
        _peripheral.delegate = self;
        _delegate = delegate;
    }
    
    _maxSendLength = 20;
    _serialRequest = Enum_SerialRequest_None;
    _serialError = 0;
    _sendBuffer = nil;
    _sendLocker = [[NSLock alloc] init];
    _modemInValue = 1;
    _modemOutValue = 1;

    return self;
}


- (void) didConnect
{
    [_peripheral discoverServices:@[self.class.uartServiceUUID, self.class.deviceInformationServiceUUID]];
    NSLog(@"Did start service discovery.");
}

- (void) didDisconnect
{
    
}

- (void) writeString:(NSString *) string
{
    NSString *string1 = [NSString stringWithString:string];
    // NSString *string2 = @"\r";
    // string1 = [string1 stringByReplacingOccurrencesOfString:@"\\r" withString:string2];
    const char *pSrc = [string1 cStringUsingEncoding:NSUTF8StringEncoding];
    char pDst[130];
    UI16 dstLen = sizeof(pDst);
    int rc = MscPubDeEscape(pSrc, strlen(pSrc), (UI8 *)pDst, &dstLen);
    
    if(rc == 0)
    {
        pDst[dstLen] = 0;   // Append null terminator
        string1 = [NSString stringWithCString:pDst encoding:NSUTF8StringEncoding];
        // string1 = [string1 stringByAppendingString:@"\r"];   // Append "\r"
        // NSLog(@"MscPubDeEscape: dstLen = %d", dstLen);
        // NSLog(@"MscPubDeEscape: pDst = %s", pDst);
        NSLog(@"MscPubDeEscape: string1 = %@", string1);
    }
    else
        NSLog(@"MscPubDeEscape: rc = %d", rc);
    
    NSDate *curdate = [NSDate date];
    NSDate *timeout = [curdate dateByAddingTimeInterval:10];   // 10 seconds timeout
    BOOL bResult = [_sendLocker lockBeforeDate:timeout];
    
    if(bResult == YES)
    {
        if(self.serialError == 0)
        {
            if(self.sendBuffer == nil)
                self.sendBuffer = [[string1 dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
            else
            {
                NSData *data = [NSData dataWithBytes:string1.UTF8String length:string1.length];
                [self.sendBuffer appendData:data];
            }
            
            // if(self.serialRequest == Enum_SerialRequest_None)
            if(_modemOutValue && self.serialRequest == Enum_SerialRequest_None)
            {
                if(self.sendBuffer.length <= _maxSendLength) self.sendLength = (int)self.sendBuffer.length;
                else self.sendLength = _maxSendLength;
                NSRange range = NSMakeRange(0, self.sendLength);
                NSData *data = [self.sendBuffer subdataWithRange:range];
                self.serialRequest = Enum_SerialRequest_WriteString;
                [self.peripheral writeValue:data forCharacteristic:self.txCharacteristic type:CBCharacteristicWriteWithResponse];
            }
        }
        
        [_sendLocker unlock];
    }
    else
        NSLog(@"WriteString: Could Not Get NSLock in 10 seconds");
}

- (void) peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error on didWriteValueForCharacteristic for characteristic %@: %@", characteristic, error);
        ++self.errorCount;
        [NSThread sleepForTimeInterval:.2];   // 200 ms
    }
    else
    {
        self.errorCount = 0;
        NSDate *curdate = [NSDate date];
        NSDate *timeout = [curdate dateByAddingTimeInterval:10];   // 10 seconds timeout
        BOOL bResult = [_sendLocker lockBeforeDate:timeout];
        if(bResult == YES)
        {
            NSRange range = NSMakeRange(0, self.sendLength);
            [self.sendBuffer replaceBytesInRange:range withBytes:NULL length:0];
            [_sendLocker unlock];
        }
        else
            NSLog(@"didWriteValueForCharacteristic 1: Could Not Get NSLock in 10 seconds");
        
        [NSThread sleepForTimeInterval:.02];   // 20 ms
    }
    
    if(self.errorCount < 3)
    {
        NSDate *curdate = [NSDate date];
        NSDate *timeout = [curdate dateByAddingTimeInterval:10];   // 10 seconds timeout
        BOOL bResult = [_sendLocker lockBeforeDate:timeout];
        if(bResult == YES)
        {
            self.sendLength = (int)[self.sendBuffer length];
            if(self.sendLength > _maxSendLength) self.sendLength = _maxSendLength;
    
            if(self.sendLength > 0)
            {
                // NSData *data = [NSData dataWithBytes:self.sendBuffer.UTF8String length:self.sendLength];
                NSRange range = NSMakeRange(0, self.sendLength);
                NSData *data = [self.sendBuffer subdataWithRange:range];
                [self.peripheral writeValue:data forCharacteristic:self.txCharacteristic type:CBCharacteristicWriteWithResponse];
            }
            else
                self.serialRequest = Enum_SerialRequest_None;

            [_sendLocker unlock];
        }
        else
            NSLog(@"didWriteValueForCharacteristic 2: Could Not Get NSLock in 10 seconds");
    }
    else
    {
        NSLog(@"Serial Write Error: %d", _errorCount);
        _serialError = 1;   // Command string writing error
    }
}

- (void) writeRawData:(NSData *) data
{
    
}

- (void) peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error discovering services: %@", error);
        return;
    }
    
    for (CBService *s in [peripheral services])
    {
        if ([s.UUID isEqual:self.class.uartServiceUUID])
        {
            NSLog(@"Found correct service");
            self.uartService = s;
            
            [self.peripheral discoverCharacteristics:@[self.class.txCharacteristicUUID, self.class.rxCharacteristicUUID] forService:self.uartService];
            [self.peripheral discoverCharacteristics:@[self.class.modemInCharacteristicUUID, self.class.modemOutCharacteristicUUID] forService:self.uartService];
        }
        else if ([s.UUID isEqual:self.class.deviceInformationServiceUUID])
        {
            [self.peripheral discoverCharacteristics:@[self.class.hardwareRevisionStringUUID] forService:s];
        }
    }
}

- (void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error discovering characteristics: %@", error);
        return;
    }
    
    for (CBCharacteristic *c in [service characteristics])
    {
        if ([c.UUID isEqual:self.class.rxCharacteristicUUID])
        {
            NSLog(@"Found RX characteristic");
            self.rxCharacteristic = c;
            [self.peripheral setNotifyValue:YES forCharacteristic:self.rxCharacteristic];
        }
        else if ([c.UUID isEqual:self.class.txCharacteristicUUID])
        {
            NSLog(@"Found TX characteristic");
            self.txCharacteristic = c;
        }
        else if ([c.UUID isEqual:self.class.modemInCharacteristicUUID])
        {
            NSLog(@"Found MODEM IN characteristic");
            self.modemInCharacteristic = c;
        }
        else if ([c.UUID isEqual:self.class.modemOutCharacteristicUUID])
        {
            NSLog(@"Found MODEM OUT characteristic");
            self.modemOutCharacteristic = c;
            [peripheral setNotifyValue:YES forCharacteristic:c];
        }
        else if ([c.UUID isEqual:self.class.hardwareRevisionStringUUID])
        {
            NSLog(@"Found Hardware Revision String characteristic");
            [self.peripheral readValueForCharacteristic:c];
        }
    }
}

- (void) peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error receiving notification for characteristic %@: %@", characteristic, error);
        return;
    }
    
    NSLog(@"Received data on a characteristic.");
    
    if (characteristic == self.rxCharacteristic)
    {
        NSData *data = [characteristic value];
        // NSLog(@">> %@" , data);
        if([data length] > 0) [self.delegate  didReceiveData:data];
    }
    else  if ([characteristic.UUID isEqual :self.class.modemOutCharacteristicUUID ])
    {
        const uint8_t  *bytes = characteristic.value.bytes;
        if( _modemOutValue != bytes[0])
        {
            _modemOutValue = bytes[0];
            NSLog(@"Modem Charateristics Value: %@" , characteristic.value);
        }
    }
    else if ([characteristic.UUID isEqual:self.class.hardwareRevisionStringUUID])
    {
        NSString *hwRevision = @"";
        const uint8_t *bytes = characteristic.value.bytes;
        for (int i = 0; i < characteristic.value.length; i++)
        {
            NSLog(@"%x", bytes[i]);
            hwRevision = [hwRevision stringByAppendingFormat:@"0x%02x, ", bytes[i]];
        }
        
        [self.delegate didReadHardwareRevisionString:[hwRevision substringToIndex:hwRevision.length-2]];
    }
}
@end

/*=============================================================================*/
/* Converts the input hex ascii character into a nibble. If character is not   */
/* valid then a o is returned */
/*=============================================================================*/
static UI16 MscPubHexCharToNibble(CHAR ch)
{
    if     ( ch <= '9' && ch >= '0' ) return (ch - '0');
    else if( ch <= 'F' && ch >= 'A' ) return (ch - 'A' + 10);
    else if( ch <= 'f' && ch >= 'a' ) return (ch - 'a' + 10);
    
    NSLog(@"%c is Not a Digit", ch);
    return 0;
}

static int StdISXDIGIT(UI8 ch)
{
    int rc = 0;
    if( (ch <= '9' && ch >= '0') ||
       (ch <= 'F' && ch >= 'A') ||
       (ch <= 'f' && ch >= 'a') )
        rc = 1;
    
    return rc;
}

/*=============================================================================*/
/*
 ** Writes a byte to the out string
 */
/*=============================================================================*/
static UI16 MscPubWriteToOutputBuf(
                                   VOID *pOutBuf,
                                   UI8 ch
                                   )
{
    if( ((SMscOutBuf *)pOutBuf)->mLen >= ((SMscOutBuf *)pOutBuf)->mMaxLen )
    {
        /* output buffer will overflow */
        return 0;
    }
    
    *((SMscOutBuf *)pOutBuf)->mpOut++ = ch;
    ((SMscOutBuf *)pOutBuf)->mLen++;
    return 1;
}

/*=============================================================================*/
/*
 ** De-escape the string specified
 */
/*=============================================================================*/
static EMscStringParseState MscPubDeEscapeString(
    FProcDeEscaped fProcDeEscaped,
    VOID *pContext,
    EMscStringParseState eState,
    UI8  *pSrc,
    UI16 *pByteCount    /* on entry length of pSrc, exit len of deescaped string */
    )
{
    UI16 nBlock = *pByteCount;
    UI8 ch;
    
    /* assume nothing gets written */
    *pByteCount = 0;
    
    if(pSrc && nBlock && fProcDeEscaped)
    {
        while(nBlock--)
        {
            switch(eState & 0xFF)
            {
                case MSC_DEESCAPE_STATE_COPYBYTE:
                    if( *pSrc == '"' )
                    {
                        eState = MSC_DEESCAPE_STATE_QUOTE;
                    }
                    else if( *pSrc == '\\' )
                    {
                        eState = MSC_DEESCAPE_STATE_BACKSLASH;
                    }
                    else
                    {
                        if( fProcDeEscaped(pContext,*pSrc) )
                        {
                            (*pByteCount)++;
                        }
                        else
                        {
                            return MSC_DEESCAPE_STATE_COPY_ERROR;
                        }
                    }
                    break;
                    
                case MSC_DEESCAPE_STATE_QUOTE:
                    if( *pSrc == '"' )
                    {
                        if( fProcDeEscaped(pContext,*pSrc) )
                        {
                            (*pByteCount)++;
                            eState = MSC_DEESCAPE_STATE_COPYBYTE;
                        }
                        else
                        {
                            return MSC_DEESCAPE_STATE_COPY_ERROR;
                        }
                    }
                    else
                    {
                        return MSC_DEESCAPE_STATE_ERROR;
                    }
                    break;
                    
                case MSC_DEESCAPE_STATE_BACKSLASH:
                    if( *pSrc == 'r' )
                    {
                        ch=0x0D;
                    }
                    else if( *pSrc == 'n' )
                    {
                        ch=0x0A;
                    }
                    else if( *pSrc == 't' )
                    {
                        ch=0x09;
                    }
                    else if( *pSrc == '"' )
                    {
                        ch=0x22;
                    }
                    else if( *pSrc == '\\' )
                    {
                        ch=0x5C;
                    }
                    else if( StdISXDIGIT(*pSrc) )
                    {
                        eState = (EMscStringParseState)(((MscPubHexCharToNibble(*pSrc)<<4)<<8)
                                                        + MSC_DEESCAPE_STATE_BACKSLASH1);
                        break;
                    }
                    else
                    {
                        return MSC_DEESCAPE_STATE_ERROR;
                    }
                    /* need to copy a byte */
                    if( fProcDeEscaped(pContext, ch) )
                    {
                        (*pByteCount)++;
                        eState = MSC_DEESCAPE_STATE_COPYBYTE;
                    }
                    else
                    {
                        return MSC_DEESCAPE_STATE_COPY_ERROR;
                    }
                    break;
                    
                case MSC_DEESCAPE_STATE_BACKSLASH1:
                    if( StdISXDIGIT(*pSrc) )
                    {
                        ch = (eState >> 8)&0xFF;
                        ch += MscPubHexCharToNibble(*pSrc);
                        if( fProcDeEscaped(pContext,ch) )
                        {
                            (*pByteCount)++;
                            eState = MSC_DEESCAPE_STATE_COPYBYTE;
                        }
                        else
                        {
                            return MSC_DEESCAPE_STATE_COPY_ERROR;
                        }
                    }
                    else
                    {
                        return MSC_DEESCAPE_STATE_ERROR;
                    }
                    break;
            }
            pSrc++;
        }
    }
    
    return eState;
}

/*=============================================================================*/
/*
 ** De-escape the block of data
 */
/*=============================================================================*/
static UWRESULTCODE    /* will be SUCCESS if no errors */
MscPubDeEscape(
    const char  *pSrc,
    UI16  nSrcLen,
    UI8  *pDst,
    UI16 *pDstLen   /* on entry, dest buf len, on exit len of deescaped string */
    )
{
    EMscStringParseState eState;
    SMscOutBuf sOutBuf;
    
    MscASSERT3(pSrc);
    MscASSERT3(pDst);
    MscASSERT3(pDstLen);
    
    /* check if source is empty */
    if(nSrcLen == 0)
    {
        *pDstLen = 0;
        return UWRESULTCODE_SUCCESS;
    }
    
    /* check if dest buffer is NULL or no length */
    if(pDst && pDstLen && (*pDstLen == 0))
    {
       if(pDstLen)
        {
            *pDstLen = 0;
        }
        return UWRESULTCODE_MSC_DEESC_ERROR;
    }
    
    
    /* now de-escape the block of data */
    sOutBuf.mLen = 0;
    sOutBuf.mMaxLen = *pDstLen;
    sOutBuf.mpOut = pDst;
    eState = MSC_DEESCAPE_STATE_COPYBYTE;
    eState = MscPubDeEscapeString(MscPubWriteToOutputBuf, &sOutBuf, eState, (UI8 *)pSrc, &nSrcLen);
    
    if(sOutBuf.mLen != nSrcLen) return UWRESULTCODE_MSC_INVALID_OUT_LEN;
    
    *pDstLen = sOutBuf.mLen;
    
    return (eState==MSC_DEESCAPE_STATE_COPYBYTE) ? UWRESULTCODE_SUCCESS : UWRESULTCODE_MSC_INVALID_STRING;
}
