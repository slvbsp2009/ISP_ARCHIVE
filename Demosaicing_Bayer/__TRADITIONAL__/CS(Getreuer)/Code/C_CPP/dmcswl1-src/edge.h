/**
 * @file edge.h
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

#ifndef _EDGE_H_
#define _EDGE_H_

struct edgestruct;

/** @brief An edge in a weighted graph */
typedef struct edgestruct
{
    int x1, y1, x2, y2;             /**< Edge endpoints                     */
    double Weight;                  /**< Edge weight                        */
    struct edgestruct *NextEdge;    /**< Pointer to next edge (linked list) */
} edge;

/** @brief A linked-list of edges */
typedef struct edgeliststruct
{
    edge *Head;             /**< Pointer to list head        */
    edge *Tail;             /**< Pointer to list tail        */
    int NumEdges;           /**< Number of edges in the list */
} edgelist;

extern edgelist NullEdgeList;


int AddEdge(edgelist *List, int x1, int y1, int x2, int y2);
void FreeEdgeList(edgelist *List);

#endif /* _EDGE_H_ */
