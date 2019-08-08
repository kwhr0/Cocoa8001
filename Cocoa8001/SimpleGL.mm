#include "SimpleGL.h"
#include <stdlib.h>

SimpleGL::SimpleGL(int _stride, int _texN, int _bufN) : stride(_stride), texN(_texN), bufN(_bufN), tex(NULL) {
	program = glCreateProgram();
	glGenVertexArrays(bufN, vao = new GLuint[bufN]);
	glGenBuffers(bufN, vbo = new GLuint[bufN]);
	glGenTextures(texN, tex = new GLuint[texN]);
	for (int i = 0; i < texN; i++) {
		glActiveTexture(GL_TEXTURE0 + i); // texture unit number == texture index
		glBindTexture(GL_TEXTURE_2D, tex[i]);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	}
	glBindTexture(GL_TEXTURE_2D, 0);
}

SimpleGL::~SimpleGL() {
	glDeleteProgram(program);
	if (texN) {
		glDeleteTextures(texN, tex);
		delete[] tex;
	}
	glDeleteBuffers(bufN, vbo);
	glDeleteVertexArrays(bufN, vao);
	delete[] vao;
	delete[] vbo;
}

void SimpleGL::Compile(const char *filename) {
	size_t len;
	GLchar *source = ReadFile(filename, &len);
	if (!source) throw "file";
	const char *p = strrchr(filename, '.');
	if (!p) throw "filename";
// first letter of file extension represents shader type
#ifdef GL_GEOMETRY_SHADER
	GLuint shader = glCreateShader(p[1] == 'v' ? GL_VERTEX_SHADER : p[1] == 'g' ? GL_GEOMETRY_SHADER :  GL_FRAGMENT_SHADER);
#else
	GLuint shader = glCreateShader(p[1] == 'v' ? GL_VERTEX_SHADER : GL_FRAGMENT_SHADER);
#endif
	GLint glLen = (GLint)len;
	glShaderSource(shader, 1, (const GLchar **)&source, &glLen);
	free(source);
	glCompileShader(shader);
	GLsizei bufSize;
	glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &bufSize);
	if (bufSize > 1) {
		printf("in file: %s\n", filename);
		GLchar *log = new GLchar[bufSize];
		glGetShaderInfoLog(shader, bufSize, &bufSize, log);
		fputs(log, stderr);
		delete[] log;
	}
	GLint compiled;
	glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
	if (compiled == GL_FALSE) throw "glCompileShader";
	glAttachShader(program, shader);
	glDeleteShader(shader);
}

void SimpleGL::Link() {
	for (int i = 0; i < (int)attribute.size(); i++)
		glBindAttribLocation(program, i, attribute[i].name.c_str());
	glLinkProgram(program);
	GLsizei bufSize;
	glGetProgramiv(program, GL_INFO_LOG_LENGTH , &bufSize);
	if (bufSize > 1) {
		GLchar *log = new GLchar[bufSize];
		glGetProgramInfoLog(program, bufSize, &bufSize, log);
		fputs(log, stderr);
		delete[] log;
	}
	GLint linked;
	glGetProgramiv(program, GL_LINK_STATUS, &linked);
	if (linked == GL_FALSE) throw "glLinkProgram";
	for (int i = 0; i < (int)uniform.size(); i++)
		uniformV.push_back(glGetUniformLocation(program, uniform[i].c_str()));
	glUseProgram(program);
	//
	for (int i = 0; i < texN; i++) SetInt(i, i); // uniform variable of texture sampler must start from 0
	for (int i = 0; i < bufN; i++) {
		BindBuffer(i);
		for (int j = 0; j < (int)attribute.size(); j++) {
			Attribute &a = attribute[j];
			glEnableVertexAttribArray(j);
			glVertexAttribPointer(j, a.size, a.type, GL_FALSE, stride, (char *)NULL + a.offset);
		}
	}
	UnbindBuffer();
}

char *SimpleGL::ReadFile(const char *filename, size_t *lenp) {
#ifdef __OBJC__
	NSString *name = [NSString stringWithUTF8String:filename];
	filename = [[[NSBundle mainBundle] pathForResource:[name stringByDeletingPathExtension] ofType:[name pathExtension]] cStringUsingEncoding:NSASCIIStringEncoding];
#endif
	FILE *fi;
	if (!(fi = fopen(filename, "rb"))) {
		fprintf(stderr, "%s not found.\n", filename);
		return NULL;
	}
	fseek(fi, 0, SEEK_END);
	size_t len = ftell(fi);
	rewind(fi);
	char *buf = (char *)malloc(len);
	if (!buf) return NULL;
	fread(buf, len, 1, fi);
	fclose(fi);
	if (lenp != NULL) *lenp = len;
	return buf;
}

#ifdef __APPLE__

int SimpleGPULoad::cnt;
double SimpleGPULoad::acc;

#if defined(__OBJC__) && !TARGET_OS_IPHONE

@implementation SimpleGLLayer

#ifdef USE_GL3
- (CGLPixelFormatObj)copyCGLPixelFormatForDisplayMask:(uint32_t)mask {
	CGLPixelFormatAttribute attribs[] = {
		kCGLPFAOpenGLProfile, (CGLPixelFormatAttribute)kCGLOGLPVersion_3_2_Core,
		kCGLPFAColorSize,     (CGLPixelFormatAttribute)24,
		kCGLPFAAlphaSize,     (CGLPixelFormatAttribute)8,
		kCGLPFAAccelerated,
		kCGLPFADoubleBuffer,
		kCGLPFASampleBuffers, (CGLPixelFormatAttribute)1,
		kCGLPFASamples,       (CGLPixelFormatAttribute)4,
		(CGLPixelFormatAttribute)0
	};
	CGLPixelFormatObj pix;
	GLint npix;
	CGLChoosePixelFormat(attribs, &pix, &npix);
	return pix;
}
#endif

- (BOOL)canDrawInCGLContext:(CGLContextObj)glContext
				pixelFormat:(CGLPixelFormatObj)pixelFormat
			   forLayerTime:(CFTimeInterval)timeInterval
				displayTime:(const CVTimeStamp *)timeStamp {
	return needsRefreshP ? *needsRefreshP : YES;
}

- (void)drawInCGLContext:(CGLContextObj)glContext
			 pixelFormat:(CGLPixelFormatObj)pixelFormat
			forLayerTime:(CFTimeInterval)timeInterval
			 displayTime:(const CVTimeStamp *)timeStamp {
	CGLSetCurrentContext(glContext);
	[self.view drawRect:self.view.bounds];
}

void SimpleGLLayerSetup(NSView *view, BOOL *_needsRefreshP) {
	SimpleGLLayer *layer = [SimpleGLLayer layer];
	layer.asynchronous = YES;
	layer->needsRefreshP = _needsRefreshP;
	layer.view = view;
	NSRect bounds = view.bounds;
	layer.bounds = *(CGRect *)&bounds;
	[view setLayer:layer];
	[view setWantsLayer:YES];
}

@end

#endif
#endif
