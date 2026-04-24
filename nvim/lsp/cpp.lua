return {
	cmd = { "clangd", "--background-index", "--clang-tidy" },
	filetypes = { "c", "cpp", "objc", "objcpp" },
	root_markers = { "CMakeLists.txt", "compile_commands.json", ".git" },
}
