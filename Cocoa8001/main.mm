int main(int argc, char *argv[]) {
	try {
		return NSApplicationMain(argc, (const char **)argv);
	}
	catch (const char *msg) {
		NSLog(@"%s\n", msg);
	}
	return 0;
}
