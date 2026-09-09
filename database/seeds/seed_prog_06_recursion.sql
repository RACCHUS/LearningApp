-- Seed the Recursion lesson into Supabase.
-- This matches the app's relational read path:
-- lessons + terms + concepts + questions + lesson_texts.

BEGIN;

-- Keep the import idempotent for repeated test runs.
DELETE FROM lesson_texts WHERE lesson_id = 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20';
DELETE FROM questions WHERE lesson_id = 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20';
DELETE FROM concepts WHERE lesson_id = 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20';
DELETE FROM terms WHERE lesson_id = 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20';
DELETE FROM lessons WHERE id = 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20';

INSERT INTO lessons (
  id,
  title,
  description,
  tags,
  user_id,
  created_at,
  updated_at
) VALUES (
  'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20',
  'Recursion',
  'Understand how a function can solve a problem by calling itself. Learn base cases, the call stack, and when recursion beats a loop.',
  ARRAY['programming', 'intermediate', 'recursion', 'algorithms'],
  NULL,
  '2026-06-30T12:00:00Z',
  '2026-06-30T12:00:00Z'
);

INSERT INTO terms (id, lesson_id, term, definition, example, emoji, order_index, created_at, updated_at, user_id) VALUES
  ('7b2b3d7d-5ef5-4d8a-9adf-9d8d4d7f0a01', 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', 'Recursion', 'A technique where a function calls itself to solve smaller instances of the same problem.', 'int factorial(int n) => n == 0 ? 1 : n * factorial(n - 1);', '🔁', 1, '2026-06-30T12:00:01Z', '2026-06-30T12:00:01Z', NULL),
  ('7b2b3d7d-5ef5-4d8a-9adf-9d8d4d7f0a02', 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', 'Base Case', 'The condition under which a recursive function returns a value directly instead of calling itself, stopping the recursion.', 'if (n == 0) return 1; // base case for factorial', '🛑', 2, '2026-06-30T12:00:02Z', '2026-06-30T12:00:02Z', NULL),
  ('7b2b3d7d-5ef5-4d8a-9adf-9d8d4d7f0a03', 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', 'Recursive Case', 'The part of a recursive function that calls itself with a smaller or simpler input, moving toward the base case.', 'return n * factorial(n - 1); // recursive case', '➡️', 3, '2026-06-30T12:00:03Z', '2026-06-30T12:00:03Z', NULL),
  ('7b2b3d7d-5ef5-4d8a-9adf-9d8d4d7f0a04', 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', 'Call Stack', 'The region of memory that tracks active function calls, pushing a frame for each call and popping it when the call returns.', 'factorial(3) → factorial(2) → factorial(1) → factorial(0) all sit on the stack at once.', '📚', 4, '2026-06-30T12:00:04Z', '2026-06-30T12:00:04Z', NULL),
  ('7b2b3d7d-5ef5-4d8a-9adf-9d8d4d7f0a05', 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', 'Stack Overflow', 'An error that occurs when recursion goes too deep and exhausts the call stack.', 'void loop() => loop(); // no base case → stack overflow', '💥', 5, '2026-06-30T12:00:05Z', '2026-06-30T12:00:05Z', NULL),
  ('7b2b3d7d-5ef5-4d8a-9adf-9d8d4d7f0a06', 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', 'Tail Recursion', 'A recursive call that is the very last operation in a function, allowing some languages to optimize it into a loop without growing the stack.', 'int sum(int n, int acc) => n == 0 ? acc : sum(n - 1, acc + n);', '🎯', 6, '2026-06-30T12:00:06Z', '2026-06-30T12:00:06Z', NULL),
  ('7b2b3d7d-5ef5-4d8a-9adf-9d8d4d7f0a07', 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', 'Tree Recursion', 'Recursion in which a single call makes two or more recursive calls, branching like a tree.', 'int fib(int n) => n < 2 ? n : fib(n - 1) + fib(n - 2);', '🌳', 7, '2026-06-30T12:00:07Z', '2026-06-30T12:00:07Z', NULL),
  ('7b2b3d7d-5ef5-4d8a-9adf-9d8d4d7f0a08', 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', 'Divide and Conquer', 'A problem-solving strategy that splits a problem into smaller sub-problems, solves each recursively, and combines the results.', 'Merge sort splits an array in half, sorts each half, then merges them.', '✂️', 8, '2026-06-30T12:00:08Z', '2026-06-30T12:00:08Z', NULL);

INSERT INTO concepts (id, lesson_id, concept_text, example_text, key_points, emoji, order_index, created_at, updated_at, user_id) VALUES
  ('8c3c4e8e-6f06-4e9b-8bee-0e9e5e8f1b01', 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', 'What Recursion Is', 'Recursion is when a function solves a problem by calling itself on a smaller version of that same problem. Each call peels off one piece of the work and hands the rest to another copy of the function. A classic example is computing a factorial: factorial(5) is just 5 × factorial(4), which is 5 × 4 × factorial(3), and so on. The function keeps deferring work to smaller calls until the problem is trivial enough to answer directly.', ARRAY['A recursive solution solves a smaller version of the same problem', 'The current call defers work to the next call', 'Factorial is a classic example'], '🔁', 501, '2026-06-30T12:00:10Z', '2026-06-30T12:00:10Z', NULL),
  ('8c3c4e8e-6f06-4e9b-8bee-0e9e5e8f1b02', 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', 'The Base Case Stops the Recursion', 'Every recursive function needs a base case — a condition that returns an answer without recursing further. The base case is what prevents infinite recursion. For factorial, the base case is factorial(0) = 1: once you reach 0 you stop calling yourself and start returning values back up. Without a base case, the function would call itself forever and crash with a stack overflow.', ARRAY['Base case ends the recursion', 'It prevents infinite loops and stack overflow', 'Every recursive function needs one'], '🛑', 502, '2026-06-30T12:00:11Z', '2026-06-30T12:00:11Z', NULL),
  ('8c3c4e8e-6f06-4e9b-8bee-0e9e5e8f1b03', 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', 'The Call Stack', 'Each time a function calls itself, the computer pushes a new frame onto the call stack to remember where it was. The recursive calls stack up until the base case is hit, then they unwind one by one as each call returns its result to the caller below it. This is why deep recursion can run out of memory: every pending call occupies a stack frame until it finishes. Understanding the stack explains both how recursion produces its answer and why it has a depth limit.', ARRAY['Each call adds a stack frame', 'Frames unwind after the base case returns', 'Deep recursion can run out of stack space'], '📚', 503, '2026-06-30T12:00:12Z', '2026-06-30T12:00:12Z', NULL),
  ('8c3c4e8e-6f06-4e9b-8bee-0e9e5e8f1b04', 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', 'Recursion vs. Iteration', 'Any recursive solution can also be written with a loop, and vice versa, but each style fits different problems. Recursion shines on naturally nested or branching data like trees, file systems, and divide-and-conquer algorithms, where it reads cleanly. Iteration is usually more memory-efficient because it does not add stack frames. A good rule of thumb: use recursion when the problem is defined in terms of smaller copies of itself, and a loop when you are simply repeating a step a fixed number of times.', ARRAY['Recursion fits nested or branching data', 'Iteration is usually more memory-efficient', 'Choose the style that matches the problem structure'], '⚖️', 504, '2026-06-30T12:00:13Z', '2026-06-30T12:00:13Z', NULL),
  ('8c3c4e8e-6f06-4e9b-8bee-0e9e5e8f1b05', 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', 'Recursion on Branching Data', 'Recursion is especially powerful when a problem splits into multiple sub-problems. Traversing a binary tree, for example, means visiting the left subtree and the right subtree — each of which is itself a smaller tree handled by the same function. This is called tree recursion because each call can spawn more than one further call. Algorithms like merge sort and quicksort use the same divide-and-conquer idea: split the input, solve each half recursively, then combine the results.', ARRAY['One call can branch into multiple calls', 'Trees and divide-and-conquer problems fit well', 'Merge sort and quicksort use the same pattern'], '🌳', 505, '2026-06-30T12:00:14Z', '2026-06-30T12:00:14Z', NULL);

INSERT INTO questions (id, lesson_id, question_text, options, correct_answer, type, explanation, order_index, created_at, updated_at, user_id) VALUES
  ('9d4d5f9f-7a17-4fac-9cff-1f0f6f9f2c01', 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', 'What is the purpose of a base case in a recursive function?', jsonb_build_array('To make the function run faster', 'To stop the recursion by returning a value without calling itself', 'To call the function with a larger input', 'To allocate more memory on the stack'), 1, 'mcq', 'The base case returns a result directly, ending the chain of calls. Faster execution is not the purpose, calling with a larger input moves away from the base case, and the base case reduces stack usage rather than allocating more memory.', 1001, '2026-06-30T12:00:20Z', '2026-06-30T12:00:20Z', NULL),
  ('9d4d5f9f-7a17-4fac-9cff-1f0f6f9f2c02', 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', 'What happens if a recursive function never reaches its base case?', jsonb_build_array('It returns null', 'It runs once and stops', 'It causes a stack overflow', 'It automatically converts to a loop'), 2, 'mcq', 'Without reaching a base case the function keeps pushing new frames until the call stack is exhausted, causing a stack overflow. It does not return null, stop on its own, or convert to a loop.', 1002, '2026-06-30T12:00:21Z', '2026-06-30T12:00:21Z', NULL),
  ('9d4d5f9f-7a17-4fac-9cff-1f0f6f9f2c03', 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', 'In factorial(4) = 4 * factorial(3), which part is the recursive case?', jsonb_build_array('The number 4', 'The multiplication operator', 'The call to factorial(3)', 'The equals sign'), 2, 'mcq', 'The recursive case is the part where the function calls itself on a smaller input — factorial(3). The other options are just pieces of the expression, not the recursive call.', 1003, '2026-06-30T12:00:22Z', '2026-06-30T12:00:22Z', NULL),
  ('9d4d5f9f-7a17-4fac-9cff-1f0f6f9f2c04', 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', 'Which data structure does the computer use to keep track of active recursive calls?', jsonb_build_array('A queue', 'The call stack', 'A hash map', 'A linked list'), 1, 'mcq', 'Function calls are tracked on the call stack, which pushes a frame per call and pops it on return. A queue is first-in-first-out, and hash maps and linked lists are not used to manage call frames.', 1004, '2026-06-30T12:00:23Z', '2026-06-30T12:00:23Z', NULL),
  ('9d4d5f9f-7a17-4fac-9cff-1f0f6f9f2c05', 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', 'When is recursion typically the most natural choice over a simple loop?', jsonb_build_array('When repeating a step a fixed number of times', 'When the problem is defined in terms of smaller copies of itself, like traversing a tree', 'When you want to use the least possible memory', 'When the input is always a single number'), 1, 'mcq', 'Recursion fits problems that break into smaller versions of themselves, such as tree traversal or divide-and-conquer. A fixed repetition suits a loop, iteration usually uses less memory, and a single number does not inherently call for recursion.', 1005, '2026-06-30T12:00:24Z', '2026-06-30T12:00:24Z', NULL),
  ('9d4d5f9f-7a17-4fac-9cff-1f0f6f9f2c06', 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', 'What makes a recursive call ''tail recursive''?', jsonb_build_array('It has no base case', 'The recursive call is the last operation performed in the function', 'It calls itself twice', 'It uses a global variable'), 1, 'mcq', 'Tail recursion means the recursive call is the final action, so no further work happens after it returns, letting some compilers optimize away the extra stack frame. Calling twice is tree recursion, a missing base case is a bug, and using a global variable is unrelated.', 1006, '2026-06-30T12:00:25Z', '2026-06-30T12:00:25Z', NULL);

INSERT INTO lesson_texts (id, lesson_id, text, order_index, created_at, updated_at, user_id) VALUES
  ('ad5e6f0a-8b28-4fbd-9d10-2f1f7f0a3d01', 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', 'Recursion works best when the problem can be broken into a smaller version of itself. The key is to make that smaller version meaningful and to stop before the problem becomes trivial.', 2001, '2026-06-30T12:00:30Z', '2026-06-30T12:00:30Z', NULL),
  ('ad5e6f0a-8b28-4fbd-9d10-2f1f7f0a3d02', 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', 'If the base case is wrong or unreachable, recursion fails fast and hard. The symptom is usually a stack overflow, which makes the base case the first thing to verify when debugging.', 2002, '2026-06-30T12:00:31Z', '2026-06-30T12:00:31Z', NULL);

-- Quick verification query for the Supabase SQL editor.
SELECT
  l.id,
  l.title,
  (SELECT count(*) FROM terms t WHERE t.lesson_id = l.id) AS term_count,
  (SELECT count(*) FROM concepts c WHERE c.lesson_id = l.id) AS concept_count,
  (SELECT count(*) FROM questions q WHERE q.lesson_id = l.id) AS question_count,
  (SELECT count(*) FROM lesson_texts lt WHERE lt.lesson_id = l.id) AS text_count
FROM lessons l
WHERE l.id = 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20';

COMMIT;