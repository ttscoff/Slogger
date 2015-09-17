#ifdef RARRAY_PTR
#else
#define RARRAY_PTR(o) (RARRAY(o)->ptr)
#define RARRAY_LEN(o) (RARRAY(o)->len)
#endif

#ifdef RSTRING_PTR
#else
#define RSTRING_PTR(o) (RSTRING(o)->ptr)
#define RSTRING_LEN(o) (RSTRING(o)->len)
#endif

VALUE mLevenshtein;
