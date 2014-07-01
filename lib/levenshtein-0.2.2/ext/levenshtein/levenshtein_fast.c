#include "ruby.h"
#include "levenshtein.h"

VALUE levenshtein_distance_fast(VALUE self, VALUE rb_o1, VALUE rb_o2, VALUE rb_threshold) {
  VALUE	*p1, *p2;
  long	l1, l2;
  long	col, row;
  int	threshold;
  int	*prev_row, *curr_row, *temp_row;
  int	curr_row_min, result;
  int	value1, value2;

  /* Be sure that all equivalent objects in rb_o1 and rb_o2 (a.eql?(b) == true) are taken from a pool (a.equal?(b) == true). */
  /* This is done in levenshtein.rb by means of Util.pool. */

  /* Get the sizes of both arrays. */

  l1	= RARRAY_LEN(rb_o1);
  l2	= RARRAY_LEN(rb_o2);

  /* Get the pointers of both arrays. */

  p1	= RARRAY_PTR(rb_o1);
  p2	= RARRAY_PTR(rb_o2);

  /* Convert Ruby's threshold to C's threshold. */

  if (!NIL_P(rb_threshold)) {
    threshold	= FIX2INT(rb_threshold);
  } else {
    threshold	= -1;
  }

  /* The Levenshtein algorithm itself. */

  /*       s1=              */
  /*       ERIK             */
  /*                        */
  /*      01234             */
  /* s2=V 11234             */
  /*    E 21234             */
  /*    E 32234             */
  /*    N 43334 <- prev_row */
  /*    S 54444 <- curr_row */
  /*    T 65555             */
  /*    R 76566             */
  /*    A 87667             */

  /* Allocate memory for both rows */

  prev_row	= (int*) ALLOC_N(int, (l1+1));
  curr_row	= (int*) ALLOC_N(int, (l1+1));

  /* Initialize the current row. */

  for (col=0; col<=l1; col++) {
    curr_row[col]	= col;
  }

  for (row=1; row<=l2; row++) {
    /* Copy the current row to the previous row. */

    temp_row	= prev_row;
    prev_row	= curr_row;
    curr_row	= temp_row;

    /* Calculate the values of the current row. */

    curr_row[0]		= row;
    curr_row_min	= row;

    for (col=1; col<=l1; col++) {
      /* Equal (cost=0) or substitution (cost=1). */

      value1	= prev_row[col-1] + ((p1[col-1] == p2[row-1]) ? 0 : 1);

      /* Insertion if it's cheaper than substitution. */

      value2	= prev_row[col]+1;
      if (value2 < value1) {
        value1	= value2;
      }

      /* Deletion if it's cheaper than substitution. */

      value2	= curr_row[col-1]+1;
      if (value2 < value1) {
        value1	= value2;
      }

      /* Keep track of the minimum value on this row. */

      if (value1 < curr_row_min) {
        curr_row_min	= value1;
      }

      curr_row[col]	= value1;
    }

    /* Return nil as soon as we exceed the threshold. */

    if (threshold > -1 && curr_row_min >= threshold) {
      free(prev_row);
      free(curr_row);

      return Qnil;
    }
  }

  /* The result is the last value on the last row. */

  result	= curr_row[l1];

  free(prev_row);
  free(curr_row);

  /* Return the Ruby version of the result. */

  return INT2FIX(result);
}

void Init_levenshtein_fast() {
  mLevenshtein	= rb_const_get(rb_mKernel, rb_intern("Levenshtein"));

  rb_define_singleton_method(mLevenshtein, "distance_fast" , levenshtein_distance_fast, 3);
}
