PERL=${PERL:-perl}
find t/tlib -name '*.pm' -print | while read pm; do
    $PERL -Ilib -c "$pm"
done
$PERL -Ilib t/all_tests.t "$@"
