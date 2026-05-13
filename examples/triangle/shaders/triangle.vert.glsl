#version 430 core

// Required for separable shader objects (glCreateShaderProgramv)
out gl_PerVertex {
    vec4 gl_Position;
};

layout(location = 0) in vec3 aPos;
layout(location = 1) in vec4 aColor;

layout(location = 0) out vec4 vertexColor;

void main() {
    gl_Position = vec4(aPos, 1.0);
    vertexColor = aColor;
}
