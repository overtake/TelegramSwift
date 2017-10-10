attribute vec4 inPosition;
attribute vec4 inTexcoord;
varying vec2 varTexcoord;

void main()
{
    gl_Position = inPosition;
    varTexcoord = inTexcoord.xy;
}
