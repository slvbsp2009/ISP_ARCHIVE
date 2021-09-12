/**
 * @file edge.c
 * @brief Weighted graph edges
 * @author Pascal Getreuer <getreuer@gmail.com>
 * 
 * Copyright (c) 2010-2011, Pascal Getreuer
 * All rights reserved.
 * 
 * This program is free software: you can use, modify and/or 
 * redistribute it under the terms of the simplified BSD License. You 
 * should have received a copy of this license along this program. If 
 * not, see <http://www.opensource.org/licenses/bsd-license.html>.
 */

#include "basic.h"
#include "edge.h"

/** @brief An empty edge list */
edgelist NullEdgeList = {NULL, NULL, 0};


/**
 * @brief Add an edge to an edgelist
 * @param List the edgelist to add edge to
 * @param x1, y1, x2, y2 edge endpoints
 * @return 1 on success, 0 on failure (memory allocation failure)
 */
int AddEdge(edgelist *List, int x1, int y1, int x2, int y2)
{
    edge *NewEdge;
    
    if(!List || !(NewEdge = (edge *)Malloc(sizeof(edge))))
        return 0;
    
    NewEdge->x1 = x1;
    NewEdge->y1 = y1;
    NewEdge->x2 = x2;    
    NewEdge->y2 = y2;
    NewEdge->Weight = 1;
    NewEdge->NextEdge = NULL;
        
    if(!List->Tail) /* Add edge to empty list */
        List->Head = List->Tail = NewEdge;
    else            /* Append the edge to the end of the list */
    {
        List->Tail->NextEdge = NewEdge;
        List->Tail = NewEdge;
    }
    
    (List->NumEdges)++;
    return 1;
}


/** 
 * @brief Free edges within an edgelist 
 * @param List the edgelist
 */
void FreeEdgeList(edgelist *List)
{
    edge *Edge, *NextEdge;
    
    for(Edge = List->Head; Edge; Edge = NextEdge)
    {
        NextEdge = Edge->NextEdge;
        Free(Edge);
    }
    
    List->Head = List->Tail = NULL;
    List->NumEdges = 0;
}

