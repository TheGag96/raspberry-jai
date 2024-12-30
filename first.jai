#import "Basic";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "Process";
#import "Sort";
#import "String";

PROJECT_NAME     :: "jai-pi";
BUILD_FOR_TARGET :: true;

// @Note: If you don't have a full Raspbian sysroot available to link against some system libraries, you may find it
//        easier to just have the compiler output an objet file and link the executable on the target machine.
LINK_TARGET_EXECUTABLE_ON_THIS_MACHINE :: true;

GCC_PATH :: "aarch64-linux-gnu-gcc"; // @TODO: find this path automatically
AR_PATH  :: "aarch64-linux-gnu-ar";  // @TODO: find this path automatically

build :: () {
  w := compiler_create_workspace(name = "raspberrypi");
  if !w {
    log_error("Couldn't create workspace!\n");
    return;
  }

  target_options := get_build_options();  // Inherit normal command line options.

  build_for_target := BUILD_FOR_TARGET;

  for target_options.compile_time_command_line {
    if it == "-target" {
      build_for_target = true;
      break;
    }
    else if it == "-host" {
      build_for_target = false;
      break;
    }
  }

  link_target_executable_on_this_machine := build_for_target && LINK_TARGET_EXECUTABLE_ON_THIS_MACHINE;

  target_options.output_executable_name                = PROJECT_NAME;

  if build_for_target {
    target_options.backend                             = .LLVM;
    target_options.output_type                         = ifx link_target_executable_on_this_machine then .EXECUTABLE else .OBJECT_FILE;
    target_options.runtime_support_definitions         = .ENTRY_POINT_AND_INIT;
    target_options.backtrace_on_crash                  = .OFF;   // @TODO: Can we enable this?
    target_options.os_target                           = .LINUX;
    target_options.cpu_target                          = .ARM64;
    target_options.llvm_options.target_system_triple   = "aarch64-unknown-linux-gnu";
    target_options.use_custom_link_command             = link_target_executable_on_this_machine;
    target_options.llvm_options.output_bitcode         = true;
    target_options.llvm_options.enable_split_modules   = false;
  }

  log(
    "Building for the %. (OS = %, CPU = %)",
    ifx build_for_target then "target hardware" else "host machine",
    target_options.os_target, target_options.cpu_target,
  );

  import_paths: [..] string;
  array_add(*import_paths, ..target_options.import_path);
  array_add(*import_paths, "modules");

  target_options.import_path = import_paths;
  set_build_options(target_options, w);

  set_build_options_dc(.{do_output = false});

  compiler_begin_intercept(w);

  add_build_file("src/main.jai", w);
  if link_target_executable_on_this_machine  custom_link(w);
  // hacky_inline_asm_removal(w);

  compiler_end_intercept(w);
}

custom_link :: (w: Workspace) {
  resulting_object_files: [] string;

  while true {
    message := compiler_wait_for_message();

    if message.kind == {
      case .PHASE; {
        phase := cast(*Message_Phase) message;

        if phase.phase == .READY_FOR_CUSTOM_LINK_COMMAND {
          args: [..] string;
          array_add(*args, GCC_PATH, "-o", "jai-pi");
          array_add(*args, ..phase.compiler_generated_object_files);
          // array_add(*args, ..phase.support_object_files);
          // array_add(*args, ..phase.system_libraries);
          array_add(*args, ..phase.user_libraries);

          // print("Link command: %\n", args);

          run_command(..args);
          compiler_custom_link_command_is_complete(w);
        }
      }

      case .COMPLETE; {
        break;
      }
    }
  }
}

#run build();