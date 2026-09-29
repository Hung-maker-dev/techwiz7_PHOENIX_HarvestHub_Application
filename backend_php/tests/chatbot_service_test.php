<?php

declare(strict_types=1);

require dirname(__DIR__) . '/src/chatbot.php';

function expectSame(mixed $expected, mixed $actual, string $case): void
{
    if ($expected !== $actual) {
        throw new RuntimeException(
            $case . ': expected ' . var_export($expected, true)
            . ', got ' . var_export($actual, true)
        );
    }
}

function expectContains(string $expected, string $actual, string $case): void
{
    if (!str_contains($actual, $expected)) {
        throw new RuntimeException($case . ': missing "' . $expected . '" in "' . $actual . '"');
    }
}

$cases = [
    [html_entity_decode('Xin ch&#224;o', ENT_QUOTES, 'UTF-8'), 'greeting'],
    [html_entity_decode('Gi&#225; c&#224; chua bao nhi&#234;u?', ENT_QUOTES, 'UTF-8'), 'product_price'],
    [html_entity_decode('C&#224; chua c&#242;n bao nhi&#234;u?', ENT_QUOTES, 'UTF-8'), 'product_stock'],
    [html_entity_decode('Cho t&#244;i danh s&#225;ch s&#7843;n ph&#7849;m', ENT_QUOTES, 'UTF-8'), 'products'],
    [html_entity_decode('T&#236;m ch&#7907; g&#7847;n t&#244;i', ENT_QUOTES, 'UTF-8'), 'markets'],
    [html_entity_decode('T&#236;m n&#244;ng tr&#7841;i', ENT_QUOTES, 'UTF-8'), 'farmers'],
    [html_entity_decode('Khung gi&#7901; nh&#7853;n h&#224;ng', ENT_QUOTES, 'UTF-8'), 'pickup_slots'],
    ['What should I cook?', 'general'],
];

foreach ($cases as [$question, $expectedIntent]) {
    expectSame($expectedIntent, chatbotClassifyIntent($question), $question);
}

$pdo = new PDO('sqlite::memory:');
$pdo->exec(
    'CREATE TABLE products (name TEXT, price REAL, unit TEXT, stock INTEGER, '
    . 'farmer_name TEXT, market_name TEXT, is_active INTEGER, is_hidden INTEGER, deleted_at TEXT)'
);
$insert = $pdo->prepare('INSERT INTO products VALUES (?, 25000, ?, 12, ?, ?, 1, 0, NULL)');
$insert->execute([
    html_entity_decode('C&#224; chua bi', ENT_QUOTES, 'UTF-8'),
    'kg',
    'Green Farm',
    'Market A',
]);

$priceAnswer = chatbotAnswerFromDatabase(
    $pdo,
    html_entity_decode('Gi&#225; c&#224; chua bi bao nhi&#234;u?', ENT_QUOTES, 'UTF-8'),
    'Vietnamese'
);
expectContains('$25,000', $priceAnswer, 'database price answer');
expectContains('12 kg', $priceAnswer, 'database product stock');

$stockAnswer = chatbotAnswerFromDatabase(
    $pdo,
    html_entity_decode('C&#224; chua bi c&#242;n bao nhi&#234;u?', ENT_QUOTES, 'UTF-8'),
    'Vietnamese'
);
expectContains('12 kg', $stockAnswer, 'database stock answer');

echo "Chatbot service tests passed.\n";
