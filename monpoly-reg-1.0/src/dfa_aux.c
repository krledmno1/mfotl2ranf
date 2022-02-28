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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <assert.h>
#include "dfa.h"
#include "mem.h"

bool all_zeros(paths pp, int no_free_vars)
{
  trace_descr tp;
  int num_indexes = 0;
  
  for (tp = pp->trace; tp; tp = tp->next)
    {
      num_indexes++;
      /* printf("all_zeros: at index %d value %d\n", num_indexes-1, no_free_vars, tp->value); */
      if (tp->value)		  
	  return false;
	
    }

  /* printf("all_zeros: %d %d\n", num_indexes, no_free_vars); */
  return (num_indexes == no_free_vars);
}

void free_space(paths state_paths, int *dfs_stack, int *vizited, int *on_stack)
{
  kill_paths(state_paths);
  mem_free(dfs_stack);
  mem_free(vizited);
  mem_free(on_stack);
}


bool isFinite(DFA *a, int no_free_vars)
{
  int *dfs_stack, *vizited, *on_stack;
  int head = 0, dfs_current_state, dfs_next_state;
  bool new_state;
  paths state_paths, pp;
  int i;
 
  dfs_stack = (int *) mem_alloc((a->ns+1)*sizeof(int));
  vizited = (int *) mem_alloc((a->ns+1)*sizeof(int)); /* intialized to 0? */
  on_stack = (int *) mem_alloc((a->ns+1)*sizeof(int)); /* intialized to 0? */

  for (i = 0; i < a->ns; i++)     
    dfs_stack[i] = vizited[i] = on_stack[i] = 0;
   
  dfs_current_state = a->s;
  dfs_stack[0] = dfs_current_state;
  
  while (head >= 0) 
    {
      dfs_current_state = dfs_stack[head];
      new_state = false;

      /* printf("Viziting state %d (head=%d)\n", dfs_current_state, head); */

      state_paths = pp = make_paths(a->bddm, a->q[dfs_current_state]);
      // Remark: we could store these, and not call make_paths again
      //         on the same node

      while (pp) 
	{
	  dfs_next_state = pp->to;
	  /* printf("Next state is %d\n", dfs_next_state); */
	  
	  if (!on_stack[dfs_next_state] && !vizited[dfs_next_state])
	    {
	      /* printf("Next state is new\n"); */
	      head++;
	      dfs_stack[head] = dfs_next_state;
	      on_stack[dfs_next_state] = 1;
	      new_state = true;
	      break;
	    }
	  else 
	    if (on_stack[dfs_next_state] && 
		(((dfs_next_state == dfs_current_state)
		  &&
		  ! ( // accepting state and loops only on 0*? then ok
		     (a->f[dfs_current_state] == 1 && all_zeros(pp, no_free_vars))
		     || // sink state? then ok	  
		     (a->f[dfs_current_state] != 1 && pp->trace == NULL)))
		 || (dfs_next_state != dfs_current_state))) // a cycle
	      {
		/* printf("loop: %d -> %d (all_zeros=%d)\n", */
		/*        dfs_current_state, */
		/*        dfs_next_state, 		   */
		/*        all_zeros(pp, no_free_vars)); */
		free_space(state_paths, dfs_stack, vizited, on_stack);
		return false;
	      }
	
	  pp = pp->next;
	}
      kill_paths(state_paths);
      if (new_state)
	continue;
      
      vizited[dfs_current_state] = 1;
      on_stack[dfs_current_state] = 0;       
      head--;
    }
  
  mem_free(dfs_stack);
  mem_free(vizited);
  mem_free(on_stack);

  return true;
}




void update_word(char *word, int index, int length, int no_free_vars, \
		 trace_descr trace, unsigned *var_indexes)
{
  trace_descr tp;
  int row;

  for (row = 0; row < no_free_vars; row++) {
    tp = trace;
    while (tp && (tp->index != var_indexes[row])) 
      tp = tp->next;
    
    if (!tp)
      word[row*length+index] = 'X';    
    else if (tp->value)      
      word[row*length+index] = '1';
    else
      word[row*length+index] = '0';

    /* printf("word[%d]=%c, (track=%d, length=%d, index=%d)\n",\ */
    /*    row*length+index,word[row*length+index],row,length,index); */
  }
}

typedef struct {
  int state;
  paths state_paths, current_path;
} stack_elem;

/* We do not do the decoding here. */
/* The code is adapted from DFA/analyze.c, DFA/printdfa.c, and
   Examples/presburger_analysis.c */

/* TODO: We should be able to handle this one!!! But here len = -1...

Accepting states: 1 
Rejecting states: 2 
Don't-care states: 0 
Transitions:
State 0:  -> state 1
State 1: @1=0 -> state 1
State 1: @1=1 -> state 2
State 2:  -> state 2
*/
char* allWords(DFA *a, int no_free_vars, unsigned *var_indexes)
{
  stack_elem *dfs_stack;
  int i, head = 0, dfs_current_state, dfs_next_state;
  paths pp;
  int *path;
  /* maximum length of a path; the initial and the sink states can be
   ignored */
  const int max_len = a->ns - 2;
  const int word_len = max_len * no_free_vars;
  char *word, *res;
  int len_res = 0, max_len_res;
  const char empty_c = 'n';

  /* printf("len = %d\n",max_len); */
  /* if (max_len <= -1) */
  /*   { */
  /*     res = (char *) mem_alloc(sizeof(char)); */
  /*     res[0] = '\0'; */
  /*     return res; */
  /*   } */
  assert(max_len >= 0);

  word = (char *) mem_alloc(word_len * sizeof(char));
  for (i = 0; i < word_len; i++)
    word[i] = empty_c; // fill with special character
  // word[word_len] = '\0'; WHY?

  max_len_res = 1024;
  res = (char *) mem_alloc(max_len_res * sizeof(char));

  dfs_stack = (stack_elem *) mem_alloc((a->ns+1) * sizeof(stack_elem));
  path = (int *) mem_alloc((a->ns+1) * sizeof(int));

  dfs_current_state = a->s;

  path[head] = dfs_current_state;
  dfs_stack[0].state = dfs_current_state;
  dfs_stack[0].state_paths = dfs_stack[0].current_path = \
    make_paths(a->bddm, a->q[dfs_current_state]);

  /* printf ("var_indexes: "); */
  /* for (i = 0; i < no_free_vars; i++) */
  /*   printf("%d -> %d ", i, var_indexes[i]); */
  /* printf ("\n"); */

  while (head >= 0)
    {
      dfs_current_state = dfs_stack[head].state;
      pp = dfs_stack[head].current_path;

      /* printf("Viziting state %d (head=%d)\n", dfs_current_state, head); */

      if (pp)
  	{
  	  dfs_next_state = pp->to;
  	  /* printf("Next state is %d\n", dfs_next_state); */
	
  	  if (dfs_next_state == dfs_current_state)
  	    {
  	      if (a->f[dfs_current_state] == 1) // we're in an accepting state
		{
		  assert(all_zeros(pp, no_free_vars));
		  assert(head <= max_len);
		  update_word(word, head-1, max_len, no_free_vars, pp->trace, var_indexes);

  		  /* printf("We are at an accepting state\n", dfs_next_state); */
		  /* printf("Path: "); */
  		  /* for (i=0; i<=head; i++) */
  		  /*   printf("%d", path[i]); */
  		  /* printf("\n"); */

		  // allocate a bigger string if needed
		  if (len_res + word_len + 1 >= max_len_res)
		    {
		      max_len_res = 2 * max_len_res;
		      char *new_res = (char*) mem_alloc(max_len_res * sizeof(char));
		      memcpy(new_res, res, len_res);
		      mem_free(res);
		      res = new_res;
		    }

		  memcpy(res + len_res, word, word_len);
		  len_res += word_len;  		
		}
  	      else // we're in a sink state
		assert(a->f[dfs_current_state] == -1 && pp->trace == NULL);

  	      // we visit the next child
  	      dfs_stack[head].current_path = dfs_stack[head].current_path -> next;
  	    }
  	  else
  	    { // we go on
  	      /* printf("Updating all fields\n"); */
	      if (head > 0 && head <= max_len) 
		update_word(word, head-1, max_len, no_free_vars, pp->trace, var_indexes);

  	      dfs_stack[head].current_path = pp->next;
  	      head++;
  	      dfs_stack[head].state = dfs_next_state;
  	      dfs_stack[head].state_paths = dfs_stack[head].current_path = \
  		make_paths(a->bddm, a->q[dfs_next_state]);
  	      path[head] = dfs_next_state;
  	    }
  	}
      else
  	{ // no more edges, we backtrack
  	  /* printf("We backtrack (head=%d)\n",head); */
	  if (head >0 && head <= max_len)
	    for (i = 0; i < no_free_vars; i++) 
	      word[i*max_len+head-1] = empty_c;

  	  kill_paths(dfs_stack[head].state_paths);
  	  head--;
  	}
    }

  /* mem_free(path);   */
  /* mem_free(dfs_stack); */

  if (len_res < max_len_res)
    res[len_res] = '\0';
  else
    assert(false);
  return res;
}





