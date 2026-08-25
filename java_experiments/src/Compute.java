class SumThread extends Thread {
    private int start;
    private int end;
    private long partialSum; // 每个线程的部分和

    public SumThread(int start, int end) {
        this.start = start;
        this.end = end;
        this.partialSum = 0;
    }

    @Override
    public void run() {
        for (int i = start; i <= end; i++) {
            partialSum += i;
        }
    }

    public long getPartialSum() {
        return partialSum;
    }
}

public class Compute {
    public static void main(String[] args) throws InterruptedException {
        // 创建4个线程，每个线程计算2500个数的和
        SumThread[] threads = new SumThread[4];
        int totalNumbers = 10000;
        int numbersPerThread = totalNumbers / threads.length;

        // 创建并启动所有线程
        for (int i = 0; i < threads.length; i++) {
            int start = i * numbersPerThread + 1;
            int end = (i == threads.length - 1) ? totalNumbers : (i + 1) * numbersPerThread;
            threads[i] = new SumThread(start, end);
            threads[i].start();
        }

        // 等待所有线程完成
        long totalSum = 0;
        for (int i = 0; i < threads.length; i++) {
            threads[i].join();
            totalSum += threads[i].getPartialSum();
        }

        // 输出结果
        System.out.println("使用" + threads.length + "个线程计算结果:");
        System.out.println("1+2+3+...+10000 = " + totalSum);

        // 验证结果（使用公式计算）
        long expectedSum = (long) totalNumbers * (totalNumbers + 1) / 2;
        System.out.println("使用公式验证结果: " + expectedSum);
        System.out.println("结果是否正确: " + (totalSum == expectedSum));
    }
}