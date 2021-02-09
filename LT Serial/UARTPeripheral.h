//
//  UARTPeripheral.h
//  nRF UART
//
//  Created by Ole Morten on 1/12/13.
//  Copyright (c) 2013 Nordic Semiconductor. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol UARTPeripheralDelegate
- (void) didReceiveData:(NSData *)data;
@optional
- (void) didReadHardwareRevisionString:(NSString *) string;
@end


@interface UARTPeripheral : NSObject <CBPeripheralDelegate>
@property CBPeripheral *peripheral;
@property id<UARTPeripheralDelegate> delegate;

typedef enum {
    Enum_SerialRequest_None,
    Enum_SerialRequest_WriteString
} EnumSerialRequest;

@property EnumSerialRequest serialRequest;
@property NSMutableData  *sendBuffer;
@property int errorCount;
@property int sendLength;
@property int maxSendLength;
@property int serialError;

+ (CBUUID *) uartServiceUUID;

- (UARTPeripheral *) initWithPeripheral:(CBPeripheral*)peripheral delegate:(id<UARTPeripheralDelegate>) delegate;

- (void) writeString:(NSString *) string;

- (void) didConnect;
- (void) didDisconnect;
@end

typedef char               CHAR;
typedef unsigned char      UI8;
typedef unsigned short     UI16;
typedef UI16               UWRESULTCODE;

#define VOID   void
#define UWRESULTCODE_SUCCESS                    0
#define UWRESULTCODE_START_MSC_MODULE           2400

enum
{
    UWRESULTCODE_MSC_INVALID_STRING         = UWRESULTCODE_START_MSC_MODULE
    ,UWRESULTCODE_MSC_INVALID_PRIORITY       /* 2401 */
    ,UWRESULTCODE_MSC_SUBST_NOARGC           /* 2402 */
    ,UWRESULTCODE_MSC_SUBST_OVERFLOW         /* 2403 */
    ,UWRESULTCODE_MSC_CONTINUE               /* 2404 */
    ,UWRESULTCODE_MSC_SUBST_INV_CHAR         /* 2405 */
    ,UWRESULTCODE_MSC_SUBST_INV_INDEX        /* 2406 */
    ,UWRESULTCODE_MSC_DEESC_ERROR            /* 2407 */
    ,UWRESULTCODE_MSC_CONSTANT_TOO_BIG       /* 2408 */
    ,UWRESULTCODE_MSC_INVALID_CONSTANT_CHAR  /* 2409 */
    ,UWRESULTCODE_MSC_INVALID_HEXSTRING      /* 240A */
    ,UWRESULTCODE_MSC_INVALID_BUFFER
    ,UWRESULTCODE_MSC_INVALID_OUT_LEN
};

typedef enum EMscDescapeStateEnumTag
{
    MSC_DEESCAPE_STATE_COPYBYTE  = 0
    ,MSC_DEESCAPE_STATE_BACKSLASH
    ,MSC_DEESCAPE_STATE_BACKSLASH1
    ,MSC_DEESCAPE_STATE_QUOTE
    ,MSC_DEESCAPE_STATE_ERROR
    ,MSC_DEESCAPE_STATE_COPY_ERROR
    
    ,MSC_DEHEX_STATE_FIRSTBYTE
    ,MSC_DEHEX_STATE_SECONDBYTE
    
    ,MSC_DEHEX_STATE_DONE
}
EMscDescapeStateEnum;

typedef UI16   EMscStringParseState;

typedef struct SMscOutBufTag
{
    UI8    *mpOut;
    UI16    mLen;
    UI16    mMaxLen;
}
SMscOutBuf;

#define MscASSERT3(p1) {if(p1 == NULL) return UWRESULTCODE_MSC_INVALID_BUFFER;}
typedef                                     UI16 (*FProcDeEscaped)(VOID *, UI8);
