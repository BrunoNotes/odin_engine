package main

import "core:fmt"
import "core:log"
import "core:os"
import "core:os/os2"
import "core:path/filepath"
import "core:strings"

ShaderType :: enum {
	vertex,
	vert,
	fragment,
	frag,
	tesscontrol,
	tesc,
	tesseval,
	tese,
	geometry,
	geom,
	compute,
	comp,
}

main :: proc() {
	context.logger = log.create_console_logger()

	cwd := os.get_current_directory()

	shaders_path := filepath.join({cwd, "shaders"})
	out_path := filepath.join({cwd, "shaders", "bin"})

	if len(os.args[1:]) > 0 {
		shaders_path = os.args[1:][0]
	}

	if len(os.args[1:]) > 1 {
		out_path = os.args[1:][1]
	}

	out_path_files, out_err := os.open(out_path)
	if out_err != os.ERROR_NONE {
		os.make_directory(out_path)
	}
	os.close(out_path_files)

	shader_files, sf_err := os.open(shaders_path)
	defer os.close(shader_files)

	if sf_err != os.ERROR_NONE {
		fmt.eprintln("Could not open directory for reading", sf_err)
		os.exit(1)
	}

	shader_fis: []os.File_Info
	defer os.file_info_slice_delete(shader_fis)

	shader_fis, sf_err = os.read_dir(shader_files, -1) // -1 reads all file infos
	if sf_err != os.ERROR_NONE {
		fmt.eprintln("Could not read directory", sf_err)
		os.exit(2)
	}

	for fi in shader_fis {
		_, file_name := filepath.split(fi.fullpath)

		if !fi.is_dir {
			if strings.has_suffix(fi.name, ".glsl") {
				// fmt.printfln("%v (%v bytes)", name, fi.size)
				file_split := strings.split(file_name, ".", context.temp_allocator)

				shader_stage := strings.concatenate(
					{"-fshader-stage=", file_split[len(file_split) - 2]},
					context.temp_allocator,
				)
				out_file, _ := strings.replace(fi.name, ".glsl", ".spv", 1, context.temp_allocator)

				out_file_path := filepath.join({out_path, out_file}, context.temp_allocator)

				cmd := os2.Process_Desc {
					command = {"glslc", shader_stage, fi.fullpath, "-o", out_file_path},
				}

				_, std_out, std_err, cmd_err := os2.process_exec(cmd, context.temp_allocator)

				if cmd_err != nil {
					log.errorf("Error compiling shader: %v", file_name)
				} else if len(std_err) > 0 {
					log.errorf(
						"Error compiling shader: %v",
						strings.clone_from_bytes(std_err, context.temp_allocator),
					)
				} else {
					log.infof("Compiled shader: %v", out_file_path)
				}
			}

		}

		free_all(context.temp_allocator)
	}

}
