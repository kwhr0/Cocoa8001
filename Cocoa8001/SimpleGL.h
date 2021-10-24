#include <string>
#include <vector>
#ifdef WIN32
#include <gl/glew.h>
#endif
#ifdef __APPLE__
#if TARGET_OS_IPHONE
#include <OpenGLES/ES2/glext.h>
#define glGenVertexArrays		glGenVertexArraysOES
#define glBindVertexArray		glBindVertexArrayOES
#define glDeleteVertexArrays	glDeleteVertexArraysOES
#else
#ifdef USE_GL3
#include <OpenGL/gl3.h>
#else
#include <OpenGL/gl.h>
#define glGenVertexArrays		glGenVertexArraysAPPLE
#define glBindVertexArray		glBindVertexArrayAPPLE
#define glDeleteVertexArrays	glDeleteVertexArraysAPPLE
#endif
#endif
#endif

class SimpleGL {
	struct Attribute {
		Attribute(std::string _name, GLint _offset, GLint _size, GLenum _type = GL_FLOAT) : name(_name), offset(_offset), size(_size), type(_type) {}
		std::string name;
		GLint offset, size;
		GLenum type;
	};
public:
	SimpleGL(int _stride, int _texN = 0, int _bufN = 1);
	virtual ~SimpleGL();
	void Compile(const char *filename);
	void Link();
	void AddAttribute(const char *name, GLint offset, GLint size, GLenum type = GL_FLOAT) {
		attribute.push_back(Attribute(name, offset, size, type));
	}
	void AddUniform(const char *name) { uniform.push_back(name); }
	void SetInt(int index, GLint value) { glUniform1i(uniformV[index], value); }
	void SetFloat(int index, GLfloat value) { glUniform1f(uniformV[index], value); }
	void SetVec4(int index, const GLfloat *value) { glUniform4fv(uniformV[index], 1, value); }
	void SetMtx33(int index, const GLfloat *value) { glUniformMatrix3fv(uniformV[index], 1, 0, value); }
	void SetMtx44(int index, const GLfloat *value) { glUniformMatrix4fv(uniformV[index], 1, 0, value); }
	void BindTexture(int index = 0) { glBindTexture(GL_TEXTURE_2D, tex[index]); }
	void UnbindTexture() { glBindTexture(GL_TEXTURE_2D, 0); }
	void BindBuffer(int index = 0) {
		glBindVertexArray(vao[index]);
		glBindBuffer(GL_ARRAY_BUFFER, vbo[index]);
	}
	void UnbindBuffer() {
		glBindVertexArray(0);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
	}
	static char *ReadFile(const char *filename, size_t *lenp = 0);
private:
	int stride, texN, bufN;
	GLuint program;
	std::vector<Attribute> attribute;
	std::vector<std::string> uniform;
	std::vector<GLint> uniformV;
	GLuint *tex, *vao, *vbo;
};

#ifdef __APPLE__

#include <CoreFoundation/CoreFoundation.h>

class SimpleGPULoad {
public:
	SimpleGPULoad() {
		t = CFAbsoluteTimeGetCurrent();
	}
	~SimpleGPULoad() {
		glFinish();
		acc += CFAbsoluteTimeGetCurrent() - t;
		if (++cnt >= 100) {
			printf("GPU: %.1fmS\n", 1000. * acc / cnt);
			cnt = 0;
			acc = 0.;
		}
	}
private:
	CFAbsoluteTime t;
	static int cnt;
	static double acc;
};

#if defined(__OBJC__) && !TARGET_OS_IPHONE
@interface SimpleGLLayer : CAOpenGLLayer {
	BOOL *needsRefreshP;
}
@property (nonatomic, weak) NSView *view;
@end
void SimpleGLLayerSetup(NSView *view, BOOL *needsRefreshP = nil);
#endif

#endif
