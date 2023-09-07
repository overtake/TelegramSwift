#include <unistd.h>
#include <pthread.h>
#include <stdio.h>
#include <sched.h>
#include <errno.h>
#include <semaphore.h>

#include <spa/utils/ringbuffer.h>

#define DEFAULT_SIZE 0x2000
#define ARRAY_SIZE 63
#define MAX_VALUE 0x10000

#ifdef __FreeBSD__
static int sched_getcpu(void) { return -1; };
#endif

static struct spa_ringbuffer rb;
static uint32_t size;
static void *data;
static sem_t sem;

static int fill_int_array(int *array, int start, int count)
{
	int i, j = start;
	for (i = 0; i < count; i++) {
		array[i] = j;
		j = (j + 1) % MAX_VALUE;
	}
	return j;
}

static int cmp_array(int *array1, int *array2, int count)
{
	int i;
	for (i = 0; i < count; i++)
		if (array1[i] != array2[i]) {
			printf("%d != %d at offset %d\n", array1[i], array2[i], i);
			return 0;
		}

	return 1;
}

static void *reader_start(void *arg)
{
	int i = 0, a[ARRAY_SIZE], b[ARRAY_SIZE];

	printf("reader started on cpu: %d\n", sched_getcpu());

	i = fill_int_array(a, i, ARRAY_SIZE);

	while (1) {
		uint32_t index;
		int32_t avail;

		avail = spa_ringbuffer_get_read_index(&rb, &index);

		if (avail >= (int32_t)(sizeof(b))) {
			spa_ringbuffer_read_data(&rb, data, size, index % size, b, sizeof(b));
			spa_ringbuffer_read_update(&rb, index + sizeof(b));

			if (index >= INT32_MAX - sizeof(a))
				break;

			spa_assert(cmp_array(a, b, ARRAY_SIZE));
			i = fill_int_array(a, i, ARRAY_SIZE);
		}
	}
	sem_post(&sem);

	return NULL;
}

static void *writer_start(void *arg)
{
	int i = 0, a[ARRAY_SIZE];
	printf("writer started on cpu: %d\n", sched_getcpu());

	i = fill_int_array(a, i, ARRAY_SIZE);

	while (1) {
		uint32_t index;
		int32_t avail;

		avail = size - spa_ringbuffer_get_write_index(&rb, &index);

		if (avail >= (int32_t)(sizeof(a))) {
			spa_ringbuffer_write_data(&rb, data, size, index % size, a, sizeof(a));
			spa_ringbuffer_write_update(&rb, index + sizeof(a));

			if (index >= INT32_MAX - sizeof(a))
				break;

			i = fill_int_array(a, i, ARRAY_SIZE);
		}
	}
	sem_post(&sem);

	return NULL;
}

#define exit_error(msg) \
do { perror(msg); exit(EXIT_FAILURE); } while (0)

int main(int argc, char *argv[])
{
	pthread_t reader_thread, writer_thread;
	struct timespec ts;

	printf("starting ringbuffer stress test\n");

	if (argc > 1)
		sscanf(argv[1], "%d", &size);
	else
		size = DEFAULT_SIZE;

	printf("buffer size (bytes): %d\n", size);
	printf("array size (bytes): %zd\n", sizeof(int) * ARRAY_SIZE);

	spa_ringbuffer_init(&rb);
	data = malloc(size);

	if (sem_init(&sem, 0, 0) != 0)
		exit_error("init_sem");

	pthread_create(&reader_thread, NULL, reader_start, NULL);
	pthread_create(&writer_thread, NULL, writer_start, NULL);

	if (clock_gettime(CLOCK_REALTIME, &ts) != 0)
		exit_error("clock_gettime");

	ts.tv_sec += 2;

	while (sem_timedwait(&sem, &ts) == -1 && errno == EINTR)
		continue;
	while (sem_timedwait(&sem, &ts) == -1 && errno == EINTR)
		continue;

	printf("read %u, written %u\n", rb.readindex, rb.writeindex);

	return 0;
}
