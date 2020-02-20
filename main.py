import pygame, sys, numpy, os, math
from pygame.locals import *

from OpenGL.GL import *
from OpenGL.GL import shaders
from OpenGL.GLU import *

import glm

# Size of the window
resolution = (1920, 1080)
full_screen = False

max_fps = 60

# Mouse look speed
look_speed = 0.003

# Maximum velocity of the camera
max_velocity = 2.0

# Acceleration when moving
speed_acceleration = 2.0

# Deceleration when not moving
speed_deceleration = 0.6

screen_center = (round(resolution[0]/2), round(resolution[1]/2))
start_position = [0.0, 0.0, 12.0]
mouse_position = None
velocity = numpy.zeros(3, numpy.float32)


def make_rotation(angle, axis):
    s = math.sin(angle)
    c = math.cos(angle)
    if axis == 0:
        return numpy.array([[1,  0,  0],
                            [0,  c, -s],
                            [0,  s,  c]], dtype=numpy.float32)
    elif axis == 1:
        return numpy.array([[c,  0,  s],
                            [0,  1,  0],
                            [-s,  0,  c]], dtype=numpy.float32)
    elif axis == 2:
        return numpy.array([[c, -s,  0],
                            [s,  c,  0],
                            [0,  0,  1]], dtype=numpy.float32)


def reorthogonalize(mat):
    u, s, v = numpy.linalg.svd(mat)
    return numpy.dot(u, v)


def center_mouse():
    if pygame.key.get_focused():
        pygame.mouse.set_pos(screen_center)


if __name__ == '__main__':
    # Setup pygame and Screen size
    pygame.init()
    pygame.display.set_mode(resolution, DOUBLEBUF | OPENGL)
    pygame.mouse.set_visible(False)
    if full_screen:
        screen = pygame.display.set_mode((0, 0), pygame.FULLSCREEN)
    center_mouse()
    mouse_position = pygame.mouse.get_pos()

    # Load, Open and Compile vertex and fragment shader
    vertex_shader_dir = os.path.join(os.path.dirname(__file__), 'vertex.glsl')
    fragment_shader_dir = os.path.join(os.path.dirname(__file__), 'fragment.glsl')
    vertex_shader = open(vertex_shader_dir).read()
    fragment_shader = open(fragment_shader_dir).read()
    program = shaders.compileProgram(shaders.compileShader(vertex_shader, GL_VERTEX_SHADER),
                                     shaders.compileShader(fragment_shader, GL_FRAGMENT_SHADER))

    # Fill uniforms of shaders with their values
    glProgramUniform2fv(program,glGetUniformLocation(program,"u_resolution"),1,resolution)
    glProgramUniform3fv(program, glGetUniformLocation(program, "u_camera_position"), 1, numpy.array([1.,1.0,12.0]))

    # Prepare fullscreen_quad to be drawn -> This is our "canvas" on which we draw
    fullscreen_quad = numpy.array([-1.0, -1.0, 0.0, 1.0, -1.0, 0.0, -1.0, 1.0, 0.0, 1.0, 1.0, 0.0], numpy.float32)
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, fullscreen_quad)
    glEnableVertexAttribArray(0)

    # Set program and camera
    glUseProgram(program)
    gluPerspective(60.0, (resolution[0]/resolution[1]), 0.1, 50.0)
    view_matrix = numpy.identity(4, numpy.float32)
    view_matrix[3, :3] = numpy.array(start_position)


    # Main rendering loop
    clock = pygame.time.Clock()
    while True:
        for event in pygame.event.get():
            if event.type == QUIT:
                sys.exit(0)
            elif event.type == KEYDOWN:
                if event.key == K_ESCAPE:
                    sys.exit(0)

        view_matrix[3, :3] += velocity * (clock.get_time() / 1000)

        pressed_keys = pygame.key.get_pressed()
        speed = 0.1

        # Mouse movement and rotations
        prev_mouse_position = mouse_position
        mouse_position = pygame.mouse.get_pos()
        dx, dy = 0, 0
        if prev_mouse_position is not None:
            center_mouse()
            time_rate = (clock.get_time() / 1000.0) / (1 / max_fps)
            dx = (mouse_position[0] - screen_center[0]) * time_rate
            dy = (mouse_position[1] - screen_center[1]) * time_rate

        if pygame.key.get_focused():
            rx = make_rotation(dx * look_speed,1)
            ry = make_rotation(dy * look_speed, 0)
            view_matrix[:3, :3] = numpy.dot(ry, numpy.dot(rx, view_matrix[:3, :3]))
            view_matrix[:3, :3] = reorthogonalize(view_matrix[:3, :3])

        # Camera movement and translations
        acceleration = numpy.zeros(3, numpy.float32)
        if pressed_keys[pygame.K_w]:
            acceleration[2] -= speed_acceleration / max_fps
        if pressed_keys[pygame.K_a]:
            acceleration[0] -= speed_acceleration / max_fps
        if pressed_keys[pygame.K_s]:
            acceleration[2] += speed_acceleration / max_fps
        if pressed_keys[pygame.K_d]:
            acceleration[0] += speed_acceleration / max_fps

        if numpy.dot(acceleration, acceleration) == 0.0:
            velocity *= speed_deceleration
        else:
            velocity += numpy.dot(view_matrix[:3, :3].T, acceleration)

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        glUniformMatrix4fv(glGetUniformLocation(program, "u_view_matrix"), 1, False, view_matrix)
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4)

        pygame.display.flip()
        clock.tick(max_fps)
        print(clock.get_fps())
