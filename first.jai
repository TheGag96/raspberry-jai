#import "Basic";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "Process";
#import "Sort";
#import "String";

PROJECT_NAME    :: "jai-pi";
OPTIMIZED_BUILD :: false;

// @Note: I was having trouble building a cross compiling GCC for the Pi with the correct GlibC version, so without
// having that, the easiest way to make a full executable is just to compile the Jai side on the host and link on the
// target. If you have a working cross-compiler, this should do the trick if you fill out the constants below.
LINK_EXECUTABLE_ON_THIS_MACHINE :: false;

GCC_PATH :: "aarch64-linux-gnu-gcc"; // @TODO: find this path automatically
AR_PATH  :: "aarch64-linux-gnu-ar";  // @TODO: find this path automatically

build :: () {
  w := compiler_create_workspace(name = "raspberrypi");
  if !w {
    log_error("Couldn't create workspace!\n");
    return;
  }

  target_options := get_build_options(w);

  target_options.backend                             = .LLVM;
  target_options.output_type                         = ifx LINK_EXECUTABLE_ON_THIS_MACHINE then .EXECUTABLE else .OBJECT_FILE;
  target_options.backtrace_on_crash                  = .OFF;   // @TODO: Can we enable this?
  target_options.output_executable_name              = PROJECT_NAME;
  target_options.os_target                           = .LINUX;
  target_options.cpu_target                          = .ARM64;
  target_options.llvm_options.target_system_triple   = "aarch64-unknown-linux-gnu";
  target_options.use_custom_link_command             = LINK_EXECUTABLE_ON_THIS_MACHINE;
  target_options.llvm_options.output_bitcode         = true;
  target_options.llvm_options.enable_split_modules   = false;

  #if OPTIMIZED_BUILD {
    set_optimization(*target_options, .OPTIMIZED);
    target_options.llvm_options.code_gen_optimization_level = 3;
    target_options.llvm_options.enable_tail_calls           = true;
    target_options.llvm_options.enable_loop_unrolling       = true;
    target_options.llvm_options.enable_slp_vectorization    = true;
    target_options.llvm_options.enable_loop_vectorization   = true;
    target_options.llvm_options.disable_inlining            = false;
  }

  import_paths: [..] string;
  array_add(*import_paths, ..target_options.import_path);
  array_add(*import_paths, "modules");

  target_options.import_path = import_paths;
  set_build_options(target_options, w);

  set_build_options_dc(.{do_output = false});

  compiler_begin_intercept(w);

  add_build_file("src/main.jai", w);
  if LINK_EXECUTABLE_ON_THIS_MACHINE  custom_link(w);
  // hacky_inline_asm_removal(w);

  compiler_end_intercept(w);
}

// Thanks to tsoding! https://github.com/tsoding/jai-wasm/blob/master/first.jai#L31-L77
// @TODO: Remove when done filling in #asm holes
hacky_inline_asm_removal :: (w: Workspace) -> [] string {
  resulting_object_files: [] string;

  while true {
    message := compiler_wait_for_message();

    if message.kind == {
      case .TYPECHECKED; {
        typechecked := cast(*Message_Typechecked) message;

        for typechecked.procedure_bodies {
          contains_asm := false;

          for it.subexpressions {
            if it.kind == .ASM {
              compiler_report("ASM DETECTED!!!", make_location(it), .WARNING);
              contains_asm = true;
            }
          }

          if contains_asm {
            body := it.expression;

            compiler_report(tprint("Removing whole body of the function % DON'T USE IT!!!", body.header.name), make_location(body), .WARNING);

            new_statements : [..] *Code_Node;
            body.block.statements = new_statements;
            compiler_modify_procedure(w, body);
          }
        }
      }

      case .PHASE; {
        phase := cast(*Message_Phase) message;

        if phase.phase == .POST_WRITE_EXECUTABLE {
          resulting_object_files = phase.compiler_generated_object_files;
        }
      }

      case .COMPLETE; {
        break;
      }
    }
  }

  return resulting_object_files;
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