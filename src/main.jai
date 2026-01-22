#import "Window_Creation";

#import "GL";
#import "Basic";

Simp  :: #import "Simp";
Input :: #import "Input";

window_width  : s32 = 500;
window_height : s32 = 500;

my_window: Window_Type;


// SHADER_PREFIX : string : "#version 330 core";
SHADER_PREFIX : string : "";

BASIC_VERTEX_SHADER :: #string  END 

#version 330 core
layout (location = 0) in vec3 position;

void main() {
   gl_Position = vec4(position.x, position.y, position.z, 1.0);
}
END

BASIC_FRAGMENT_SHADER :: #string END
#version 330 core
out vec4 FragColor;

void main() {
    FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
}
END


check_compile_errors :: (shader : GLuint) -> success: bool, info_log : string {
    success : s32;
    glGetShaderiv (shader, GL_COMPILE_STATUS, *success);
    if !success {
        info_len : s32;
        glGetShaderiv (shader, GL_INFO_LOG_LENGTH, *info_len);
        info_data := cast (*u8) alloc (info_len,, temp);
        glGetShaderInfoLog (shader, xx info_len, xx *info_len, info_data);
        result : string;
        result.data = info_data;
        result.count = info_len;

        return false, result;
    }

    return true, "";
}

check_link_errors :: (program : GLuint) -> success: bool, info_log : string {
    success : s32;
    glGetProgramiv (program, GL_LINK_STATUS, *success);
    if !success {
        info_len : s32;
        glGetProgramiv (program, GL_INFO_LOG_LENGTH, *info_len);
        info_data := cast (*u8) alloc (info_len,, temp);
        glGetProgramInfoLog (program, xx info_len, xx *info_len, info_data);
        result : string;
        result.data = info_data;
        result.count = info_len;

        return false, result;
    }

    return true, "";
}

create_shader_program :: (vertex_source : string, fragment_source : string) -> program_handle: GLuint, success: bool {
    // in order to operate opengl you pretty much have to understand the entire rendering pipeline for rasterization on the gpu at a high level
	// OpenGL requires us to create at least a vertex shader and a
	// fragment shader, to create a shader program that it can execute.

	vertex_shader_handle := glCreateShader (GL_VERTEX_SHADER);
	defer glDeleteShader (vertex_shader_handle);

    shaders := *u8.[   SHADER_PREFIX.data ,    vertex_source.data ];
    lengths := s32.[xx SHADER_PREFIX.count, xx vertex_source.count];
	glShaderSource (vertex_shader_handle, 2, shaders.data, lengths.data);
	glCompileShader (vertex_shader_handle);
	ok, info_log := check_compile_errors (vertex_shader_handle);
	if !ok {
		log_error("Could not compile vertex shader %", info_log);
		return 0, false;
	}

	fragment_shader_handle := glCreateShader (GL_FRAGMENT_SHADER);
	defer glDeleteShader (fragment_shader_handle);
	shaders[1] =    fragment_source.data;
	lengths[1] = xx fragment_source.count;
	glShaderSource (fragment_shader_handle, 2, shaders.data, lengths.data);
	glCompileShader (fragment_shader_handle);

	ok, info_log = check_compile_errors (fragment_shader_handle);
	if !ok {
		log_error ("Could not compile fragment shader: %", info_log);
		return 0, false;
	}

	result := glCreateProgram ();
	glAttachShader(result, vertex_shader_handle);
	glAttachShader(result, fragment_shader_handle);

	glLinkProgram(result);
	ok, info_log = check_link_errors (result);

	if !ok {
		log_error ("Could not link shader program: %", info_log);
		glDeleteProgram (result);
		return 0, false;
	}

	return result, true;
}

setup_draw_data :: () -> vao_handle: GLuint, vbo_handle: GLuint, ibo_handle: GLuint {

    positions := float.[
        0.5,  0.5,  0.0, // top right
        0.5,  -0.5, 0.0, // bottom right
        -0.5, -0.5, 0.0, // bottom left
        -0.5, 0.5,  0.0  // top left
    ];

    indices := GLuint.[
        // note that we start from 0!
        0, 1, 3, // first Triangle
        1, 2, 3  // second Triangle
    ];

    vao_handle, vbo_handle, ibo_handle: GLuint;

    // store the vertices
    glGenBuffers(1, *vbo_handle);
    log("generated vbo with idx: %", vbo_handle);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_handle);
	defer glBindBuffer (GL_ARRAY_BUFFER, 0);
    glBufferData(GL_ARRAY_BUFFER, size_of(float) * positions.count, positions.data, GL_STATIC_DRAW);

    // store the indices
    glGenBuffers(1, *ibo_handle);
    log("generated ibo with idx: %", ibo_handle);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo_handle);
	defer glBindBuffer (GL_ELEMENT_ARRAY_BUFFER, 0);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, size_of(GLuint) * indices.count, indices.data, GL_STATIC_DRAW);

    // create a vao for this object to store all the data
    glGenVertexArrays(1, *vao_handle);
    log("generated vao with idx: %", vao_handle);

    // we're storing it in the vao, so enable it so that opengl knows that
    glBindVertexArray(vao_handle);
	defer glBindVertexArray (0);

    // this makes it so that opengl will actually render the attributes for 0, it's not require for the next line to work.
    glEnableVertexAttribArray(0);

    // setup how to move through the data
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * size_of(float), cast (*void ) 0);

    return vao_handle, vbo_handle, ibo_handle;
}


main :: () {


    my_window = create_window(window_width, window_height, "mwe_opengl");
    Simp.set_render_target(my_window);


	program_handle, success := create_shader_program(BASIC_VERTEX_SHADER, BASIC_FRAGMENT_SHADER);
	if !success
        log("shader compilation failed");
		// return false;

    vao_handle, vbo_handle, ibo_handle := setup_draw_data();
    log("after setting up draw data we got vao: % vbo: % ibo: %", vao_handle, vbo_handle, ibo_handle);

    quit := false;
    while !quit {
        Input.update_window_events();
        for Input.events_this_frame {
            if it.type == .QUIT then quit = true;

            if it.type == {
              case .KEYBOARD;
                if it.key_pressed && it.key_code == .ESCAPE {
                    quit = true;
                }
            }
        }


		Simp.update_window (my_window);
        Simp.clear_render_target(.15, .08, .08, 1);

		glDepthMask (GL_TRUE);
		glEnable (GL_DEPTH_TEST);

		glClear (GL_DEPTH_BUFFER_BIT);

        glBindVertexArray(vao_handle); 
        glBindBuffer(GL_ARRAY_BUFFER, vbo_handle);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo_handle);
        glUseProgram(program_handle);

        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, cast (*void) 0);

        Simp.swap_buffers(my_window);
    }
}
