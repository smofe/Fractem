import pygame
from pygame.locals import *

from OpenGL.GL import *
from OpenGL.GL import shaders
from OpenGL.GLU import *
import numpy
import os

resolution = (1920, 1080)
full_screen = False


def main():
    # Setup pygame and Screen size
    pygame.init()
    display = resolution
    pygame.display.set_mode(display, DOUBLEBUF|OPENGL)
    if full_screen:
        screen = pygame.display.set_mode((0, 0), pygame.FULLSCREEN)

    # Load, Open and Compile vertex and fragment shader
    vertex_shader_dir = os.path.join(os.path.dirname(__file__), 'vertex.glsl')
    fragment_shader_dir = os.path.join(os.path.dirname(__file__), 'fragment.glsl')
    vertex_shader = open(vertex_shader_dir).read()
    fragment_shader = open(fragment_shader_dir).read()

    program = shaders.compileProgram(shaders.compileShader(vertex_shader, GL_VERTEX_SHADER),
                                     shaders.compileShader(fragment_shader, GL_FRAGMENT_SHADER))

    # Prepare fullscreen_quad to be drawn -> This is our "canvas" on which we draw
    fullscreen_quad = numpy.array([-1.0, -1.0, 0.0, 1.0, -1.0, 0.0, -1.0, 1.0, 0.0, 1.0, 1.0, 0.0], numpy.float32)
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, fullscreen_quad)
    glEnableVertexAttribArray(0)

    # Fill uniforms of shaders with their values
    loc = glGetUniformLocation(program,"u_resolution");
    glProgramUniform2fv(program,loc,1,resolution)

    # Set program and camera
    glUseProgram(program)
    gluPerspective(90, (display[0]/display[1]), 0.1, 50.0)

    # Main rendering loop
    quit = False
    while not quit:
        for e in pygame.event.get():
            if e.type in (QUIT, KEYDOWN):
                quit = True
        glClear(GL_COLOR_BUFFER_BIT)

        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4)
        pygame.display.flip()

main()
