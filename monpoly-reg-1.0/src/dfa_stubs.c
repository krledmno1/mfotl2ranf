/*
 * This file is part of MonPoly-Reg.
 *
 * Copyright (C) 2014 ETH Zurich.
 * Contact:  ETH Zurich (Eugen Zalinescu: eugen.zalinescu@inf.ethz.ch)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * as published by the Free Software Foundation, version 2.1 of the
 * License.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this program. If not, see
 * http://www.gnu.org/licenses/lgpl-2.1.html. 
 */

#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/custom.h>
#include <assert.h>
#include "dfa.h"
#include "dfa_aux.h"


/* Accessing the DFA* part of an OCaml custom block */
#define DFA_val(v) (*((DFA **) Data_custom_val(v)))



void finalize_dfa(value v)
{
  DFA *a = DFA_val(v);
  // printf("dfaFree called by finalize on %p\n", a);
  dfaFree(a);
}

/* Encapsulation of opaque DFAs as OCaml custom blocks. */
static struct custom_operations mona_dfa_ops = {
  "ch.ethz.infsec.mona_dfa",
  finalize_dfa,
  //custom_finalize_default,
  custom_compare_default,
  custom_hash_default,
  custom_serialize_default,
  custom_deserialize_default
};





/* Allocating an OCaml custom block to hold the given DFA* */
CAMLprim static value alloc_dfa(DFA *a)
{
  value v = alloc_custom(&mona_dfa_ops, sizeof(DFA*), 1, 1);
  DFA_val(v) = a;
  /* printf("new automaton: %p\n",a); */
  return v;
}

CAMLprim value caml_mona_print_dfa(value a, value str)
{
  CAMLparam2(a,str);

  DFA *dfa = DFA_val(a);
  char *s = String_val(str);
  /* printf("dfa %s address is %p\n",s,dfa); */
  fflush(stdout);

  CAMLreturn(Val_unit);
}


CAMLprim value caml_mona_dfaTrue()
{
  CAMLparam0();
  /* printf("dfaTrue()\n"); */
  CAMLreturn(alloc_dfa(dfaTrue()));
}

CAMLprim value caml_mona_dfaFalse()
{
  CAMLparam0();
  /* printf("dfaFalse()\n"); */
  CAMLreturn(alloc_dfa(dfaFalse()));
}

CAMLprim value caml_mona_dfaEq2(value i, value j)
{
  CAMLparam2(i, j);

  /* printf("dfaEq2()\n"); */
  CAMLreturn(alloc_dfa(dfaEq2(Int_val(i), Int_val(j))));
}

CAMLprim value caml_mona_dfaPresbConst(value i, value n)
{
  CAMLparam2(i, n);

  int c = Int_val(n);
  assert(c >= 0);

  /* printf("dfaPresbConst()\n"); */
  CAMLreturn(alloc_dfa(dfaPresbConst(Int_val(i), c)));
}

CAMLprim value caml_mona_dfaNegation(value a)
{
  CAMLparam1(a);
  dfaNegation(DFA_val(a));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_mona_dfaProduct(value a1, value a2, value mode)
{
  CAMLparam3(a1, a2, mode);
  dfaProductType pt;

  switch Int_val(mode)
    {
    case 0: pt = dfaIMPL; break;
    case 1: pt = dfaBIIMPL; break;
    case 2: pt = dfaAND; break;
    case 3: pt = dfaOR; break;
    }

  DFA *prod = dfaProduct(DFA_val(a1), DFA_val(a2), pt);
  DFA *a = dfaMinimize(prod);
  dfaFree(prod);
  
  /* printf("dfaProduct()\n"); */
  CAMLreturn(alloc_dfa(a));
}

CAMLprim value caml_mona_dfaProject(value a, value i)
{
  CAMLparam2(a, i);

  DFA *proj = dfaProject(DFA_val(a), Int_val(i));
  DFA *b = dfaMinimize(proj);
  dfaFree(proj);

  /* printf("dfaProject()\n"); */
  CAMLreturn(alloc_dfa(b));
}


CAMLprim value caml_mona_dfaMinimize(value a)
{
  CAMLparam1(a);
  /* printf("dfaMinimize()\n"); */
  CAMLreturn(alloc_dfa(dfaMinimize(DFA_val(a))));
}

CAMLprim value caml_mona_dfaReplaceIndices(value a, value ml_indices)
{
  CAMLparam2(a, ml_indices);
  int i, len = Wosize_val(ml_indices);
  unsigned int *indices = 
    malloc(sizeof(unsigned int) * len);
  
  for (i=0; i < len; i++)
    {
      indices[i] = Int_val(Field(ml_indices, i));
    }
  
  dfaReplaceIndices(DFA_val(a), indices);
	 
  free(indices);
  CAMLreturn0;
}


CAMLprim value caml_mona_dfaCopy(value a)
{
  CAMLparam1(a);
  /* printf("dfaCopy()\n"); */
  CAMLreturn(alloc_dfa(dfaCopy(DFA_val(a))));
}




CAMLprim value caml_mona_dfaPrintVerbose(value a)
{
  CAMLparam1(a);
  dfaPrintVerbose(DFA_val(a));
  CAMLreturn(Val_unit);
}


/* void dfaPrint(DFA *a, int num, char *names [], unsigned indices []) */
CAMLprim value caml_mona_dfaPrint(value a, value num, value ml_names, value ml_indices)
{
  CAMLparam4(a, num, ml_names, ml_indices);
  
  int i, len = Int_val(num);
  char **names = malloc(sizeof(char*) * len);
  unsigned int *indices = malloc(sizeof(unsigned int) * len);
  
  assert(len > 0 && len == Wosize_val(ml_names));
  for (i=0; i < len; i++)
    {
      names[i] = String_val(Field(ml_names, i));
    }

  assert(len = Wosize_val(ml_indices));
  for (i=0; i < len; i++)
    {
      indices[i] = Int_val(Field(ml_indices, i));
    }
  
  dfaPrint(DFA_val(a), Int_val(num), names, indices);
	 
  free(names);
  free(indices);
  CAMLreturn0;
}

/* void dfaPrintGraphviz(DFA *a, int num, unsigned indices []) */
CAMLprim value caml_mona_dfaPrintGraphviz(value a, value num, value ml_indices)
{
  CAMLparam3(a, num, ml_indices);
  
  int i, len = Int_val(num);
  unsigned int *indices = malloc(sizeof(unsigned int) * len);
  
  assert(len > 0 && len == Wosize_val(ml_indices));
  for (i=0; i < len; i++)
    {
      indices[i] = Int_val(Field(ml_indices, i));
    }
  
  dfaPrintGraphviz(DFA_val(a), Int_val(num), indices);
	 
  free(indices);
  CAMLreturn0;
}

CAMLprim value caml_mona_dfaImport(value ml_file)
{
  CAMLparam1(ml_file);

  char **vars;
  int *orders;
  char *file;
  value dfa;
  
  file = String_val(ml_file);
  /* printf("dfaImport()\n"); */
  DFA *a = dfaImport(file, &vars, &orders);
  if (a == 0) {
    fprintf(stderr, "Fatal error importing file. \
Check the path given by the -mona_dir option. Current path is: %s\n",file);
    exit(1);
  }
    
  dfa = alloc_dfa(a);

  mem_free(vars);
  mem_free(orders);

  CAMLreturn(dfa);
}



CAMLprim value caml_isFinite(value a, value num)
{
  CAMLparam2(a, num);
  CAMLreturn(Val_bool(isFinite(DFA_val(a), Int_val(num))));
}

CAMLprim value caml_allWords(value a, value num, value ml_indices)
{
  CAMLparam3(a, num, ml_indices);  

  int i, no_free_vars = Int_val(num);
  unsigned int *indices = malloc(sizeof(unsigned int) * no_free_vars);
  
  assert((no_free_vars > 0) && no_free_vars <= Wosize_val(ml_indices));
  for (i=0; i < no_free_vars; i++)
    {
      indices[i] = Int_val(Field(ml_indices, i));
    }

  char *s = allWords(DFA_val(a), Int_val(num), indices);
  free(indices);

  CAMLlocal1(ml_s);
  ml_s = caml_copy_string(s);
  mem_free(s);

  CAMLreturn(ml_s);
}


CAMLprim value caml_numberOfStates(value a)
{
  CAMLparam1(a);
  CAMLreturn(Val_int(DFA_val(a)->ns));
}

CAMLprim value caml_isFinal(value a, value s)
{
  CAMLparam2(a, s);
  DFA *dfa = DFA_val(a);
  CAMLreturn(Val_bool(dfa->f[Int_val(s)] == 1));
}

