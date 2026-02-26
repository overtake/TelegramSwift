
#import <QuartzCore/CALayer.h>

@interface CAPortalLayer : CALayer
{
}

+ (BOOL)CA_automaticallyNotifiesObservers:(Class)arg1;
+ (BOOL)_hasRenderLayerSubclass;
@property BOOL allowsBackdropGroups;
@property BOOL matchesTransform;
@property BOOL matchesPosition;
@property BOOL matchesOpacity;
@property BOOL hidesSourceLayer;
@property unsigned int sourceContextId;
@property unsigned long long sourceLayerRenderId;
@property __weak CALayer *sourceLayer;
- (_Bool)_renderLayerDefinesProperty:(unsigned int)arg1;
- (struct Layer *)_copyRenderLayer:(struct Transaction *)arg1 layerFlags:(unsigned int)arg2 commitFlags:(unsigned int *)arg3;
- (void)layerDidBecomeVisible:(BOOL)arg1;
- (void)didChangeValueForKey:(id)arg1;

@end
