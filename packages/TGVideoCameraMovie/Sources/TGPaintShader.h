#import <Foundation/Foundation.h>
#import <OpenGL/gl.h>

@interface TGPaintShader : NSObject

@property (nonatomic, readonly) GLuint program;
@property (nonatomic, readonly) NSDictionary *uniforms;

- (instancetype)initWithVertexShader:(NSString *)vertexShader fragmentShader:(NSString *)fragmentShader attributes:(NSArray *)attributes uniforms:(NSArray *)uniforms;

- (GLuint)uniformForKey:(NSString *)key;

- (void)cleanResources;

@end
