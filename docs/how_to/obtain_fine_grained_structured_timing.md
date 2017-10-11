For each suite (`pre-suite`, `tests`, `post-suite`, `pre-cleanup`) that's run, Beaker will generate a `#{suite}-times.txt` file in the log/latest and log/{log-prefix} dated directories. This file provides more fine-grained runtimes for each test case, and also shows how it is structured. It is outputted in a manner that makes it easy to parse for further post-processing (e.g. to run timing experiments across different platforms).

# Example

Assume that we are running the `tests` suite, and we have two files representing our test cases: `file-one.rb` and `file-two.rb`. Here are their contents:

## file-one.rb
```
test_name "1" do
  step "1" do
  end
  step "2" do
  end
  step "3" do
  end
end
```

## file-two.rb
```
test_name "1" do
  step "1" do
    step "2" do
    end
  end
  step "3" do
    raise "This step is meant to fail!"
  end
  step "4" do
  end
end
```

Further, assume that both test cases ran to completion under the slow failure mode. The structured timing tree would then be something like:

## file-one.rb
```
                                        ("file-one.rb", 30s)
                                          ("Test 1", 20s)                               
                        ("Step 1", 10s)   ("Step 2", 5s)    ("Step 3", 5s)
```

## file-two.rb
```
                                        ("file-two.rb", X)
                                          ("Test 1", X)
                       ("Step 1", 20s)                      ("Step 3", X) 
                       ("Step 2", 20s)
```

where notice that for `file-two.rb` since we had a failure, the overall test case failed. Failures are marked with an `X`. Any preceding steps that succeeded are preseved, and ensuing steps are skipped (which is why there is no node for "Step 4").

Using these trees, our `tests-times.txt` file would have the following output:
```
("file-one.rb", 30s)
  ("Test 1", 20s)
    ("Step 1", 10s)
    ("Step 2", 5s)
    ("Step 3", 5s)
 
("file-two.rb", X)
  ("Test 1", X)
    ("Step 1", 20s)
      ("Step 2", 20s)
    ("Step 3", X)
```

# Aside

This extension is a prototype, and thus does not properly handle skipped or pending test cases (although it would not be a substantial task to do so). Furthermore, Steps and Tests with the same name are allowed (e.g. step `2` in `file-one.rb` can be named step `1`). Also, the timing information does not print to `STDOUT`, unlike the corresponding `#{suite}-summary.txt` file. So this information can only be viewed by opening the `#{suite}-times.txt` file.
