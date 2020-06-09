// Create the dte.svh and dte.h interface files to span between
// SystemVerilog and C++ without drift. To use this file, use gcc -E
// to expand macros with either GENERATE_CXX defined to make the C++
// version or GENERATE_SVH to make the SystemVerilog version of the
// definitions.

#define FE_REQ_TYPES(M)                         \
  M(dteNone),                                   \
  M(dteDiagFunc),                               \
  M(dteDiagRead),                               \
  M(dteDiagWrite),                              \
  M(dteMisc),                                   \
  M(dteReleaseEBUSData)

#define MISC_FUNC_TYPES(M)                      \
  M(clrCROBAR)


#ifdef GENERATE_CXX
#define CXX_FE_TYPE(E)    E
#define CXX_FE_NAME(E)   #E
#define CXX_MISC_TYPE(E)  E
#define CXX_MISC_NAME(E) #E

typedef enum {
  FE_REQ_TYPES(CXX_FE_TYPE)
} tReqType;

static const char *reqTypeNames[] = {
  FE_REQ_TYPES(CXX_FE_NAME)
};

typedef enum {
  MISC_FUNC_TYPES(CXX_MISC_TYPE)
} tMiscFuncType;

static const char *miscFuncNames[] = {
  MISC_FUNC_TYPES(CXX_MISC_NAME)
};
#endif


#ifdef GENERATE_SVH
#define SVH_FE_TYPE(E)    E
#define SVH_FE_NAME(E)   #E
#define SVH_MISC_TYPE(E)  E
#define SVH_MISC_NAME(E) #E

typedef enum {
  FE_REQ_TYPES(SVH_FE_TYPE)
} tReqType;

typedef enum {
  MISC_FUNC_TYPES(SVH_MISC_TYPE)
} tMiscFuncType;
#endif
