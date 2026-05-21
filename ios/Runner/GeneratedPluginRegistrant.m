//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<camera_avfoundation/CameraPlugin.h>)
#import <camera_avfoundation/CameraPlugin.h>
#else
@import camera_avfoundation;
#endif

#if __has_include(<rtmp_broadcaster/RtmppublisherPlugin.h>)
#import <rtmp_broadcaster/RtmppublisherPlugin.h>
#else
@import rtmp_broadcaster;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [CameraPlugin registerWithRegistrar:[registry registrarForPlugin:@"CameraPlugin"]];
  [RtmppublisherPlugin registerWithRegistrar:[registry registrarForPlugin:@"RtmppublisherPlugin"]];
}

@end
