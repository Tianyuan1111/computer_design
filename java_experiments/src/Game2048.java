import javax.swing.*;
import java.awt.*;
import java.awt.event.KeyAdapter;
import java.awt.event.KeyEvent;
import java.io.*;
import java.util.Random;

public class Game2048 extends JFrame {
    private static final int GRID_SIZE = 4;
    private static final int CELL_SIZE = 100;
    private static final int GAP = 10;
    private static final String SCORE_FILE = "2048_best_score.dat";
    private static final Color[] TILE_COLORS = {
            new Color(0xCDC1B4), // 空单元格
            new Color(0xEEE4DA), // 2
            new Color(0xEDE0C8), // 4
            new Color(0xF2B179), // 8
            new Color(0xF59563), // 16
            new Color(0xF67C5F), // 32
            new Color(0xF65E3B), // 64
            new Color(0xEDCF72), // 128
            new Color(0xEDCC61), // 256
            new Color(0xEDC850), // 512
            new Color(0xEDC53F), // 1024
            new Color(0xEDC22E)  // 2048
    };
    private static final Color[] TEXT_COLORS = {
            new Color(0x776E65),
            Color.WHITE
    };

    private int[][] board;
    private int score;
    private int bestScore;
    private boolean gameOver;
    private final JPanel gamePanel;
    private final JLabel scoreLabel;
    private final JLabel bestScoreLabel;
    private final Random random;
    private final JButton newGameButton;

    public Game2048() {
        setTitle("2048 Game");
        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        setLayout(new BorderLayout());
        setResizable(false);

        // 初始化变量
        board = new int[GRID_SIZE][GRID_SIZE];
        score = 0;
        bestScore = loadBestScore();
        gameOver = false;
        random = new Random();

        // 顶部面板 - 标题
        JPanel topPanel = new JPanel();
        topPanel.setLayout(new BorderLayout());
        topPanel.setBackground(new Color(0xFAF8EF));
        topPanel.setBorder(BorderFactory.createEmptyBorder(20, 20, 20, 20));

        JLabel titleLabel = new JLabel("2048");
        titleLabel.setFont(new Font("Arial", Font.BOLD, 60));
        titleLabel.setForeground(new Color(0x776E65));

        // 分数面板（右侧）
        JPanel scorePanel = new JPanel();
        scorePanel.setLayout(new GridLayout(1, 2, 10, 0));
        scorePanel.setOpaque(false);

        // 当前分数面板
        JPanel currentScorePanel = createScorePanel("SCORE", "0");
        scoreLabel = (JLabel) ((JPanel) currentScorePanel.getComponent(1)).getComponent(0);

        // 最佳分数面板
        JPanel bestScorePanel = createScorePanel("BEST", String.valueOf(bestScore));
        bestScoreLabel = (JLabel) ((JPanel) bestScorePanel.getComponent(1)).getComponent(0);

        scorePanel.add(currentScorePanel);
        scorePanel.add(bestScorePanel);

        // NEW GAME按钮
        newGameButton = new JButton("NEW GAME");
        newGameButton.setFont(new Font("Arial", Font.BOLD, 16));
        newGameButton.setBackground(new Color(0x8F7A66));
        newGameButton.setForeground(Color.WHITE);
        newGameButton.setFocusPainted(false);
        newGameButton.setBorderPainted(false);
        newGameButton.setCursor(new Cursor(Cursor.HAND_CURSOR));
        newGameButton.setPreferredSize(new Dimension(150, 40));
        newGameButton.addActionListener(e -> resetGame());

        // 右侧面板（分数 + 按钮）
        JPanel rightPanel = new JPanel();
        rightPanel.setLayout(new BoxLayout(rightPanel, BoxLayout.Y_AXIS));
        rightPanel.setOpaque(false);
        rightPanel.add(scorePanel);
        rightPanel.add(Box.createVerticalStrut(10));
        rightPanel.add(newGameButton);

        topPanel.add(titleLabel, BorderLayout.WEST);
        topPanel.add(rightPanel, BorderLayout.EAST);

        // 游戏面板
        gamePanel = new JPanel() {
            @Override
            protected void paintComponent(Graphics g) {
                super.paintComponent(g);
                drawBoard(g);
            }
        };
        gamePanel.setPreferredSize(new Dimension(
                GRID_SIZE * (CELL_SIZE + GAP) + GAP,
                GRID_SIZE * (CELL_SIZE + GAP) + GAP
        ));
        gamePanel.setBackground(new Color(0xBBADA0));

        // 底部面板 - 提示
        JPanel bottomPanel = new JPanel();
        bottomPanel.setBackground(new Color(0xFAF8EF));
        bottomPanel.setBorder(BorderFactory.createEmptyBorder(20, 20, 20, 20));
        JLabel hintLabel = new JLabel("使用方向键移动方块");
        hintLabel.setFont(new Font("Arial", Font.PLAIN, 14));
        hintLabel.setForeground(new Color(0x776E65));
        bottomPanel.add(hintLabel);

        add(topPanel, BorderLayout.NORTH);
        add(gamePanel, BorderLayout.CENTER);
        add(bottomPanel, BorderLayout.SOUTH);

        // 键盘监听
        addKeyListener(new KeyAdapter() {
            @Override
            public void keyPressed(KeyEvent e) {
                if (gameOver && e.getKeyCode() != KeyEvent.VK_R) {
                    return;
                }

                boolean moved = false;
                switch (e.getKeyCode()) {
                    case KeyEvent.VK_UP:
                        moved = moveUp();
                        break;
                    case KeyEvent.VK_DOWN:
                        moved = moveDown();
                        break;
                    case KeyEvent.VK_LEFT:
                        moved = moveLeft();
                        break;
                    case KeyEvent.VK_RIGHT:
                        moved = moveRight();
                        break;
                    case KeyEvent.VK_R:
                        resetGame();
                        return;
                }

                if (moved) {
                    addRandomTile();
                    updateScore();
                    gamePanel.repaint();

                    if (isGameOver()) {
                        gameOver = true;
                        showGameOverDialog();
                    }
                }
            }
        });

        pack();
        setLocationRelativeTo(null);

        // 初始化游戏
        resetGame();
    }

    private JPanel createScorePanel(String title, String value) {
        JPanel panel = new JPanel();
        panel.setLayout(new BoxLayout(panel, BoxLayout.Y_AXIS));
        panel.setBackground(new Color(0xBBADA0));
        panel.setBorder(BorderFactory.createEmptyBorder(10, 20, 10, 20));

        JLabel titleLabel = new JLabel(title);
        titleLabel.setFont(new Font("Arial", Font.BOLD, 16));
        titleLabel.setForeground(new Color(0xEEE4DA));
        titleLabel.setAlignmentX(Component.CENTER_ALIGNMENT);

        JPanel valuePanel = new JPanel();
        valuePanel.setOpaque(false);
        JLabel valueLabel = new JLabel(value);
        valueLabel.setFont(new Font("Arial", Font.BOLD, 24));
        valueLabel.setForeground(Color.WHITE);
        valuePanel.add(valueLabel);

        panel.add(titleLabel);
        panel.add(valuePanel);

        return panel;
    }

    private int loadBestScore() {
        try {
            File file = new File(SCORE_FILE);
            if (file.exists()) {
                try (DataInputStream dis = new DataInputStream(new FileInputStream(file))) {
                    return dis.readInt();
                }
            }
        } catch (IOException e) {
            System.out.println("无法读取最佳分数: " + e.getMessage());
        }
        return 0;
    }

    private void saveBestScore() {
        try (DataOutputStream dos = new DataOutputStream(new FileOutputStream(SCORE_FILE))) {
            dos.writeInt(bestScore);
        } catch (IOException e) {
            System.out.println("无法保存最佳分数: " + e.getMessage());
        }
    }

    private void resetGame() {
        board = new int[GRID_SIZE][GRID_SIZE];
        score = 0;
        gameOver = false;
        addRandomTile();
        addRandomTile();
        updateScore();
        gamePanel.repaint();
        requestFocus();
    }

    private void addRandomTile() {
        java.util.List<Point> emptyCells = new java.util.ArrayList<>();
        for (int i = 0; i < GRID_SIZE; i++) {
            for (int j = 0; j < GRID_SIZE; j++) {
                if (board[i][j] == 0) {
                    emptyCells.add(new Point(i, j));
                }
            }
        }

        if (!emptyCells.isEmpty()) {
            Point cell = emptyCells.get(random.nextInt(emptyCells.size()));
            board[cell.x][cell.y] = (random.nextInt(10) == 0) ? 4 : 2;
        }
    }

    private boolean moveUp() {
        boolean moved = false;
        for (int j = 0; j < GRID_SIZE; j++) {
            for (int i = 1; i < GRID_SIZE; i++) {
                if (board[i][j] != 0) {
                    int k = i;
                    while (k > 0 && board[k - 1][j] == 0) {
                        board[k - 1][j] = board[k][j];
                        board[k][j] = 0;
                        k--;
                        moved = true;
                    }
                    if (k > 0 && board[k - 1][j] == board[k][j]) {
                        board[k - 1][j] *= 2;
                        score += board[k - 1][j];
                        board[k][j] = 0;
                        moved = true;
                    }
                }
            }
        }
        return moved;
    }

    private boolean moveDown() {
        boolean moved = false;
        for (int j = 0; j < GRID_SIZE; j++) {
            for (int i = GRID_SIZE - 2; i >= 0; i--) {
                if (board[i][j] != 0) {
                    int k = i;
                    while (k < GRID_SIZE - 1 && board[k + 1][j] == 0) {
                        board[k + 1][j] = board[k][j];
                        board[k][j] = 0;
                        k++;
                        moved = true;
                    }
                    if (k < GRID_SIZE - 1 && board[k + 1][j] == board[k][j]) {
                        board[k + 1][j] *= 2;
                        score += board[k + 1][j];
                        board[k][j] = 0;
                        moved = true;
                    }
                }
            }
        }
        return moved;
    }

    private boolean moveLeft() {
        boolean moved = false;
        for (int i = 0; i < GRID_SIZE; i++) {
            for (int j = 1; j < GRID_SIZE; j++) {
                if (board[i][j] != 0) {
                    int k = j;
                    while (k > 0 && board[i][k - 1] == 0) {
                        board[i][k - 1] = board[i][k];
                        board[i][k] = 0;
                        k--;
                        moved = true;
                    }
                    if (k > 0 && board[i][k - 1] == board[i][k]) {
                        board[i][k - 1] *= 2;
                        score += board[i][k - 1];
                        board[i][k] = 0;
                        moved = true;
                    }
                }
            }
        }
        return moved;
    }

    private boolean moveRight() {
        boolean moved = false;
        for (int i = 0; i < GRID_SIZE; i++) {
            for (int j = GRID_SIZE - 2; j >= 0; j--) {
                if (board[i][j] != 0) {
                    int k = j;
                    while (k < GRID_SIZE - 1 && board[i][k + 1] == 0) {
                        board[i][k + 1] = board[i][k];
                        board[i][k] = 0;
                        k++;
                        moved = true;
                    }
                    if (k < GRID_SIZE - 1 && board[i][k + 1] == board[i][k]) {
                        board[i][k + 1] *= 2;
                        score += board[i][k + 1];
                        board[i][k] = 0;
                        moved = true;
                    }
                }
            }
        }
        return moved;
    }

    private void updateScore() {
        scoreLabel.setText(String.valueOf(score));

        // 更新最佳分数
        if (score > bestScore) {
            bestScore = score;
            bestScoreLabel.setText(String.valueOf(bestScore));
            saveBestScore();
        }
    }

    private boolean isGameOver() {
        // 检查是否有空单元格
        for (int i = 0; i < GRID_SIZE; i++) {
            for (int j = 0; j < GRID_SIZE; j++) {
                if (board[i][j] == 0) {
                    return false;
                }
            }
        }

        // 检查是否有可合并的相邻单元格
        for (int i = 0; i < GRID_SIZE; i++) {
            for (int j = 0; j < GRID_SIZE; j++) {
                int current = board[i][j];
                if (i > 0 && board[i - 1][j] == current) return false;
                if (i < GRID_SIZE - 1 && board[i + 1][j] == current) return false;
                if (j > 0 && board[i][j - 1] == current) return false;
                if (j < GRID_SIZE - 1 && board[i][j + 1] == current) return false;
            }
        }

        return true;
    }

    private void drawBoard(Graphics g) {
        Graphics2D g2d = (Graphics2D) g;
        g2d.setRenderingHint(RenderingHints.KEY_ANTIALIASING,
                RenderingHints.VALUE_ANTIALIAS_ON);

        for (int i = 0; i < GRID_SIZE; i++) {
            for (int j = 0; j < GRID_SIZE; j++) {
                int x = j * (CELL_SIZE + GAP) + GAP;
                int y = i * (CELL_SIZE + GAP) + GAP;
                int value = board[i][j];

                // 绘制单元格背景
                int colorIndex = value == 0 ? 0 : (int) (Math.log(value) / Math.log(2));
                colorIndex = Math.min(colorIndex, TILE_COLORS.length - 1);
                g2d.setColor(TILE_COLORS[colorIndex]);
                g2d.fillRoundRect(x, y, CELL_SIZE, CELL_SIZE, 10, 10);

                // 绘制数字
                if (value != 0) {
                    String text = String.valueOf(value);
                    Font font = getFontForValue(value);
                    g2d.setFont(font);

                    FontMetrics fm = g2d.getFontMetrics();
                    int textWidth = fm.stringWidth(text);
                    int textHeight = fm.getAscent();

                    // 选择文字颜色
                    g2d.setColor(value > 4 ? TEXT_COLORS[1] : TEXT_COLORS[0]);

                    // 居中绘制文字
                    g2d.drawString(text,
                            x + (CELL_SIZE - textWidth) / 2,
                            y + (CELL_SIZE + textHeight) / 2 - 4);
                }
            }
        }
    }

    private Font getFontForValue(int value) {
        if (value < 10) return new Font("Arial", Font.BOLD, 48);
        if (value < 100) return new Font("Arial", Font.BOLD, 42);
        if (value < 1000) return new Font("Arial", Font.BOLD, 36);
        return new Font("Arial", Font.BOLD, 30);
    }

    private void showGameOverDialog() {
        int option = JOptionPane.showConfirmDialog(this,
                "游戏结束！你的分数是: " + score + "\n重新开始游戏？",
                "游戏结束",
                JOptionPane.YES_NO_OPTION);

        if (option == JOptionPane.YES_OPTION) {
            resetGame();
        }
    }

    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> {
            Game2048 game = new Game2048();
            game.setFocusable(true);
            game.requestFocusInWindow();
            game.setVisible(true);
        });
    }
}
