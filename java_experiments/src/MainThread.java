class MyThread extends Thread {
    int[] results;
    int start;
    int end;
    int value;

    public MyThread(int[] results, int start, int end, int value) {
        this.results = results;
        this.start = start;
        this.end = end;
        this.value = value;
    }

    @Override
    public void run() {
        for (int i = start; i < end; i++) {
            results[i] = value;
        }
    }
}

public class MainThread {
    public static void main(String[] args) throws InterruptedException {
        int[] tasks = new int[10];
        Thread t1 = new MyThread(tasks, 0, 5, 1);
        Thread t2 = new MyThread(tasks, 5, 10, 2);

        t1.start();
        t2.start();

        t1.join();
        t2.join();

        System.out.println("任务完成结果:");
        for (int i = 0; i < 10; i++) {
            System.out.println("tasks[" + i + "] = " + tasks[i]);
        }
    }
}