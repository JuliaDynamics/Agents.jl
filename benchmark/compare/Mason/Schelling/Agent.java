package sim.app.schelling;

import sim.field.grid.IntGrid2D;
import sim.engine.SimState;
import sim.util.IntBag;
import sim.util.Int2D;
import sim.engine.Steppable;

public class Agent implements Steppable
{
    private static final long serialVersionUID = 1L;
    Int2D loc;
    IntBag neighborsX;
    IntBag neighborsY;

    public Agent(final int x, final int y) {
        this.neighborsX = new IntBag(9);
        this.neighborsY = new IntBag(9);
        this.loc = new Int2D(x, y);
    }

    public void step(final SimState state) {
        final Schelling sch = (Schelling)state;
        final int[][] locs = sch.neighbors.field;
        final int x = this.loc.x;
        final int y = this.loc.y;
        if (locs[x][y] < 2) {
            return;
        }
        if (sch.emptySpaces.numObjs == 0) {
            return;
        }
        final IntGrid2D neighbors = sch.neighbors;
        final int x2 = this.loc.x;
        final int y2 = this.loc.y;
        final int neighborhood = sch.neighborhood;
        final IntGrid2D neighbors2 = sch.neighbors;
        neighbors.getMooreLocations(x2, y2, neighborhood, 0, true, this.neighborsX, this.neighborsY);
        double val = 0.0;
        final int threshold = sch.threshold;
        final int numObjs = this.neighborsX.numObjs;
        final int[] objsX = this.neighborsX.objs;
        final int[] objsY = this.neighborsY.objs;
        final int myVal = locs[x][y];
        for (int i = 0; i < numObjs; ++i) {
            if (locs[objsX[i]][objsY[i]] == myVal && (objsX[i] != x || objsY[i] != y)) {
                val += 1.0 / Math.sqrt((x - objsX[i]) * (x - objsX[i]) + (y - objsY[i]) * (y - objsY[i]));
                if (val >= threshold) {
                    return;
                }
            }
        }
        final int newLocIndex = state.random.nextInt(sch.emptySpaces.numObjs);
        final Int2D newLoc = (Int2D)sch.emptySpaces.objs[newLocIndex];
        sch.emptySpaces.objs[newLocIndex] = this.loc;
        final int swap = locs[newLoc.x][newLoc.y];
        locs[newLoc.x][newLoc.y] = locs[this.loc.x][this.loc.y];
        locs[this.loc.x][this.loc.y] = swap;
        this.loc = newLoc;
    }
}
