#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Structure for holding data
typedef struct TextFile {
	struct CharData {
		unsigned char ch;
		unsigned int *pos;
		unsigned int count;
	} *chars;
	unsigned int count;
} TextFile;

// Find character position from character
int find_char(TextFile *file, unsigned char ch) {
	if (!file) return -1;

	for (unsigned int i = 0; i < file->count; ++i) {
		if (file->chars[i].ch == ch) {
			return i;
		}
	}

	return -1;
}

// Free text file
void free_file(TextFile *file) {
	for (unsigned int i = 0; i < file->count; ++i) {
		free(file->chars[i].pos);
	}
	free(file->chars);
}

// Add char to text file structure
void add_to_file(TextFile *file, unsigned char ch, unsigned int pos) {
	if (!file) return;

	int i = find_char(file, ch);
	if (i < 0) {
		struct CharData *tmp = (struct CharData *)realloc(file->chars, (file->count + 1) * sizeof(struct CharData));
		if (!tmp) return;

		file->chars = tmp;
		file->chars[file->count].ch = ch;
		file->chars[file->count].pos = malloc(sizeof(unsigned int));
		if (!file->chars[file->count].pos) return;
		file->chars[file->count].pos[0] = pos;
		file->chars[file->count].count = 1;
		file->count++;
	} else {
		unsigned int *tmp = (unsigned int *)realloc(file->chars[i].pos, (file->chars[i].count + 1) * sizeof(unsigned int));
		if (!tmp) return;
		file->chars[i].pos = tmp;
		file->chars[i].pos[file->chars[i].count] = pos;
		file->chars[i].count++;
	}
}

// Get the text from the text file
char *get_text_file(TextFile *file, unsigned int *size) {
	if (!file) {
		if (size) *size = 0;
		return NULL;
	}

	// Determine the size of the output text
	unsigned int total = 0;
	for (unsigned int i = 0; i < file->count; ++i) {
		total += file->chars[i].count;
	}

	// Allocate and clear memory for output
	char *output = (char *)malloc(sizeof(char) * (total + 1));
	if (!output) {
		if (size) *size = 0;
		return NULL;
	}

	// Fill output buffer with the text data
	unsigned int pos = 0;
	for (unsigned int i = 0; i < file->count; ++i) {
		for (unsigned int j = 0; j < file->chars[i].count; ++j) {
			output[file->chars[i].pos[j]] = file->chars[i].ch;
		}
	}
	output[total] = '\0';

	// Return size if pointer given
	if (size) *size = total;
	return output;
}

void save_file(TextFile *file, const char *filename) {
	if (!file || !filename) return;
	FILE *fp;

	if (!(fp = fopen(filename, "wb"))) {
		fprintf(stderr, "Error: Failed to open file '%s' for writing.\n", filename);
		return;
	}

	// Write character data
	for (unsigned int i = 0; i < file->count; ++i) {
		fwrite(&file->chars[i].ch, sizeof(unsigned char), 1, fp);
		fwrite(&file->chars[i].count, sizeof(unsigned int), 1, fp);
		fwrite(file->chars[i].pos, sizeof(unsigned int), file->chars[i].count, fp);
	}
	fwrite(&file->count, sizeof(unsigned int), 1, fp);
	fclose(fp);
}

void load_file(TextFile *file, const char *filename) {
	if (!file || !filename) return;
	FILE *fp;

	if (!(fp = fopen(filename, "rb"))) {
		fprintf(stderr, "Error: Failed to open file '%s' for reading.\n", filename);
		return;
	}

	// Read the total count of characters
	fseek(fp, -sizeof(unsigned int), SEEK_END);
	fread(&file->count, sizeof(unsigned int), 1, fp);
	fseek(fp, 0, SEEK_SET);
	printf("Total chars: %u\n", file->count);

	// Allocates memory for the characters
	file->chars = (struct CharData *)malloc(file->count * sizeof(struct CharData));
	if (!file->chars) {
		fclose(fp);
		return;
	}

	// Read character data
	for (unsigned int i = 0; i < file->count; ++i) {
		// Read in character
		fread(&file->chars[i].ch, sizeof(unsigned char), 1, fp);

		// Read number of positions for current character
		fread(&file->chars[i].count, sizeof(unsigned int), 1, fp);

		// Allocate memory for the positions
		file->chars[i].pos = (unsigned int *)malloc(file->chars[i].count * sizeof(unsigned int));
		if (!file->chars[i].pos) {
			free(file->chars);
			fclose(fp);
			return;
		}

		// Read in positions
		fread(file->chars[i].pos, sizeof(unsigned int), file->chars[i].count, fp);
	}
	fclose(fp);
}

void load_text_file(TextFile *file, const char *filename) {
	FILE *fp;

	if ((fp = fopen(filename, "rt")) == NULL) {
		fprintf(stderr, "Error: Cannot open file '%s' for reading.\n", filename);
		return;
	}

	int c = 0;
	unsigned int pos = 0;

	while ((c = getc(fp)) != EOF) {
		add_to_file(file, c, pos);
		++pos;
	}

	fclose(fp);
}

void status_file(TextFile *file) {
	if (!file) return;

	// Get total positions
	unsigned int total = 0;
	for (unsigned int i = 0; i < file->count; ++i) {
		total = file->chars[i].pos[file->chars[i].count - 1];
	}

	// Print results
	printf("Total Characters: %u\nTotal Positions: %u\n", file->count, total);
}

void print_file(TextFile *file) {
	if (!file) return;

	unsigned int size;
	char *text_data = get_text_file(file, &size);

	printf("%s\n", text_data);
	free(text_data);
}

int main(int argc, char **argv) {
	if (argc != 2) {
		fprintf(stderr, "Usage: %s [file.ext]\n", argv[0]);
		return 1;
	}

	TextFile file = (TextFile){NULL, 0};
	load_text_file(&file, argv[1]);
	save_file(&file, "output.dat");
	print_file(&file);
	free_file(&file);

/*
	file = (TextFile){NULL, 0};
	load_file(&file, "output.dat");
	print_file(&file);
	free_file(&file);
*/

	return 0;
}

