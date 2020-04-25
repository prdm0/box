context('circular dependencies')

test_that('cyclic dependencies load in finite time', {
    xyz::use(mod/cyclic_a)
    expect_true(TRUE)
})

test_that('cyclic import fully loads dependencies', {
    xyz::use(a = mod/cyclic_a)
    xyz::use(b = mod/cyclic_b)

    expect_equal(a$name, 'a')
    expect_equal(b$name, 'b')
    expect_equal(a$b_name(), 'b')
    expect_equal(b$a_name(), 'a')
    expect_equal(a$b$name, 'b')
    expect_equal(b$a$name, 'a')
    expect_equal(a$b$a$b_name(), 'b')
    expect_equal(a$b$a$name, 'a')
    expect_equal(b$a$b$a_name(), 'a')
    expect_equal(b$a$b$name, 'b')
})
