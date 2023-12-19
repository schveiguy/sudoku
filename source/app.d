import std.stdio;
import raylib;

enum conflictColor = Colors.RED;
enum selectedColor = Colors.GREEN;
enum relatedColor = Colors.DARKGREEN;
enum digitFontSize = 74;
enum pencilFontSize = 24;

struct Cell
{
    bool[9] pencil;
    int digit; // 0 - 9
    bool input; // is an input digit
    bool conflict; // marked when this cell is in conflict
    bool selected; // is cell selected
    bool related; // is cell related to selection

    void draw(Rectangle target)
    {
        if(conflict)
        {
            DrawRectangleRec(target, ColorAlpha(conflictColor, 0.3));
        }
        if(selected)
        {
            DrawRectangleRec(target, ColorAlpha(selectedColor, 0.3));
        }
        else if(related)
        {
            DrawRectangleRec(target, ColorAlpha(relatedColor, 0.3));
        }
        if(digit != 0)
        {
            auto num = TextFormat("%d", digit);
            // center the text
            Vector2 tstart = Vector2(target.x, target.y) + Vector2((target.width - MeasureText(num, digitFontSize)) / 2, (target.height - digitFontSize) / 2);
            DrawTextEx(GetFontDefault(), num, tstart, digitFontSize, 0, input ? Colors.BLACK : Colors.BLUE);
        }
        else
        {
            // see if any pencil marks are present
            foreach(i; 0 .. 9)
            {
                if(pencil[i])
                {
                    auto psize = target.width / 3;
                    auto num = TextFormat("%d", i + 1);
                    Vector2 tstart = Vector2(target.x, target.y) + Vector2(i % 3, i / 3) * psize + Vector2((psize - MeasureText(num, pencilFontSize))/ 2, (psize - pencilFontSize) / 2);
                    DrawTextEx(GetFontDefault(), num, tstart, pencilFontSize, 0, Colors.GRAY);
                }
            }
        }
    }
}

struct Puzzle
{
    Cell[9][9] cells;

    int selectedRow = -1;
    int selectedColumn = -1;

    private struct Range(alias getcell)
    {
        Cell[9][] cells;
        size_t left;
        size_t idx;
        bool empty() => left == 0;
        ref Cell front() {
            return getcell(cells, idx);
        }
        ref Cell opIndex(size_t n) => getcell(cells, idx + n);
        ref Cell back() => getcell(cells, idx + left - 1);
        size_t length() => left;

        void popFront() {
            ++idx;
            --left;
        }

        void popBack() {
            --left;
        }
    }

    auto rowRange(int row)
    {
        static ref Cell getByRow(Cell[9][] cells, size_t idx) => cells[idx / 9][idx % 9];
        return Range!getByRow(cells[], 9, row * 9);
    }
    auto colRange(int col)
    {
        static ref Cell getByCol(Cell[9][] cells, size_t idx) => cells[idx % 9][idx / 9];
        return Range!getByCol(cells[], 9, col * 9);
    }

    auto sectionRange(int sec)
    {
        int r = sec / 3 * 3;

        static ref Cell getBySec(Cell[9][] cells, size_t idx) => cells[idx % 3][idx / 3];
        return Range!getBySec(cells[r .. r + 3], 9, sec % 3 * 9);
    }

    auto relatedRange(int row, int col)
    {
        import std.range;
        return chain(rowRange(row), colRange(col), sectionRange(row / 3 * 3 + col / 3));
    }

    void check()
    {
        foreach(ref r; cells)
            foreach(ref c; r)
                c.conflict = false;
        // which row/col has the existing number
        static void checkIt(R)(R rng)
        {
            Cell*[9] matches;
            foreach(ref c; rng)
            {
                if(c.digit == 0)
                    continue;
                if(matches[c.digit - 1] is null)
                {
                    matches[c.digit - 1] = &c;
                }
                else
                {
                    matches[c.digit - 1].conflict = true;
                    c.conflict = true;
                }
            }
        }
            
        foreach(v; 0 .. 9)
        {
            checkIt(rowRange(v));
            checkIt(colRange(v));
            checkIt(sectionRange(v));
        }
    }

    void set(string[] inputs)
    {
        foreach(r, s; inputs)
            foreach(c, d; s)
            {
                if(d >= '1' && d <= '9')
                {
                    cells[r][c].digit = d - '0';
                    cells[r][c].input = true;
                }
                else
                {
                    cells[r][c].digit = 0;
                    cells[r][c].input = false;
                }
            }
    }

    void select(int row, int col)
    {
        if(selectedRow != -1)
        {
            // deselect current selection
            cells[selectedRow][selectedColumn].selected = false;
            foreach(ref c; relatedRange(selectedRow, selectedColumn))
                c.related = false;
        }
        if(row >= 0 && row < 9 && col >= 0 && col < 9)
        {
            selectedRow = row;
            selectedColumn = col;
        }
        else
            selectedRow = selectedColumn = -1;
        if(selectedRow != -1)
        {
            // select new selection
            cells[selectedRow][selectedColumn].selected = true;
            foreach(ref c; relatedRange(selectedRow, selectedColumn))
                c.related = true;
        }
    }

    void doAllPencils()
    {
        foreach(r; 0 .. 9)
        {
            foreach(c; 0 .. 9)
            {
                if(cells[r][c].digit == 0)
                {
                    cells[r][c].pencil[] = true;
                    foreach(ce; relatedRange(r, c))
                    {
                        if(ce.digit)
                            cells[r][c].pencil[ce.digit - 1] = false;
                    }
                }
            }
        }
    }

    Cell* selectedCell()
    {
        if(selectedRow != -1)
            return &cells[selectedRow][selectedColumn];
        return null;
    }
}

void main()
{
    validateRaylibBinding();
    InitWindow(1200, 900, "sudoku");
    int cellSize = 100;
    SetTargetFPS(60);
    Puzzle puzzle;
    puzzle.set([
        "..3...12.",
        "294..7...",
        "5..284..7",
        ".6.3..95.",
        "1.8...2.6",
        ".45..6.3.",
        "3..518..9",
        "...6..872",
        ".89...5.."
    ]);
    puzzle.check();
    while(!WindowShouldClose())
    {
        int row = GetMouseY / cellSize;
        int col = GetMouseX / cellSize;
        puzzle.select(row, col);
        if(IsKeyPressed(KeyboardKey.KEY_P))
        {
            puzzle.doAllPencils();
        }
        void setDigit(int digit)
        {
            if(auto sel = puzzle.selectedCell)
            {
                if(!sel.input)
                {
                    sel.digit = digit;
                    puzzle.check();
                }
            }
        }
        if(IsKeyPressed(KeyboardKey.KEY_ZERO))  setDigit(0);
        if(IsKeyPressed(KeyboardKey.KEY_ONE))   setDigit(1);
        if(IsKeyPressed(KeyboardKey.KEY_TWO))   setDigit(2);
        if(IsKeyPressed(KeyboardKey.KEY_THREE)) setDigit(3);
        if(IsKeyPressed(KeyboardKey.KEY_FOUR))  setDigit(4);
        if(IsKeyPressed(KeyboardKey.KEY_FIVE))  setDigit(5);
        if(IsKeyPressed(KeyboardKey.KEY_SIX))   setDigit(6);
        if(IsKeyPressed(KeyboardKey.KEY_SEVEN)) setDigit(7);
        if(IsKeyPressed(KeyboardKey.KEY_EIGHT)) setDigit(8);
        if(IsKeyPressed(KeyboardKey.KEY_NINE))  setDigit(9);
        BeginDrawing();
        ClearBackground(Colors.WHITE);
        foreach(i; 0 .. 10)
        {
            Vector2 beg = Vector2(cellSize * i, 0);
            DrawLineEx(beg, beg + Vector2(0, cellSize * 9), i % 3 == 0 ? 3 : 1, Colors.BLACK);
            beg = Vector2(0, cellSize * i);
            DrawLineEx(beg, beg + Vector2(cellSize * 9, 0), i % 3 == 0 ? 3 : 1, Colors.BLACK);
        }
        foreach(r; 0 .. 9)
            foreach(c; 0 .. 9)
                puzzle.cells[r][c].draw(Rectangle(c * cellSize, r * cellSize, cellSize, cellSize));
        EndDrawing();
    }
}
