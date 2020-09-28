package sim.app.schelling;

import sim.engine.Steppable;
import sim.util.Int2D;
import sim.util.Interval;
import sim.util.Bag;
import sim.field.grid.IntGrid2D;
import sim.engine.SimState;

public class Schelling extends SimState
{
    private static final long serialVersionUID = 1L;
    public int gridHeight;
    public int gridWidth;
    public int neighborhood;
    public int threshold;
    public double redProbability;
    public double blueProbability;
    public double emptyProbability;
    public double unavailableProbability;
    public IntGrid2D neighbors;
    public Bag emptySpaces;
    public static final int EMPTY = 0;
    public static final int UNAVAILABLE = 1;
    public static final int RED = 2;
    public static final int BLUE = 3;
    
    public int getGridHeight() {
        return this.gridHeight;
    }
    
    public void setGridHeight(final int val) {
        if (val > 0) {
            this.gridHeight = val;
        }
    }
    
    public int getGridWidth() {
        return this.gridWidth;
    }
    
    public void setGridWidth(final int val) {
        if (val > 0) {
            this.gridWidth = val;
        }
    }
    
    public int getNeighborhood() {
        return this.neighborhood;
    }
    
    public void setNeighborhood(final int val) {
        if (val > 0) {
            this.neighborhood = val;
        }
    }
    
    public int getThreshold() {
        return this.threshold;
    }
    
    public void setThreshold(final int val) {
        if (val >= 0) {
            this.threshold = val;
        }
    }
    
    public Object domRedProbability() {
        return new Interval(0.0, 1.0);
    }
    
    public double getRedProbability() {
        return this.redProbability;
    }
    
    public void setRedProbability(final double val) {
        if (val >= 0.0 && val <= 1.0) {
            this.redProbability = val;
        }
    }
    
    public Object domBlueProbability() {
        return new Interval(0.0, 1.0);
    }
    
    public double getBlueProbability() {
        return this.blueProbability;
    }
    
    public void setBlueProbability(final double val) {
        if (val >= 0.0 && val <= 1.0) {
            this.blueProbability = val;
        }
    }
    
    public Object domEmptyProbability() {
        return new Interval(0.0, 1.0);
    }
    
    public double getEmptyProbability() {
        return this.emptyProbability;
    }
    
    public void setEmptyProbability(final double val) {
        if (val >= 0.0 && val <= 1.0) {
            this.emptyProbability = val;
        }
    }
    
    public Object domUnavailableProbability() {
        return new Interval(0.0, 1.0);
    }
    
    public double getUnavailableProbability() {
        return this.unavailableProbability;
    }
    
    public void setUnavailableProbability(final double val) {
        if (val >= 0.0 && val <= 1.0) {
            this.unavailableProbability = val;
            double total = this.redProbability + this.blueProbability + this.emptyProbability;
            if (total == 0.0) {
                total = 1.0;
            }
            this.redProbability *= (1.0 - this.unavailableProbability) / total;
            this.blueProbability *= (1.0 - this.unavailableProbability) / total;
            this.emptyProbability *= (1.0 - this.unavailableProbability) / total;
        }
    }
    
    public Schelling(final long seed) {
        this(seed, 50, 50);
    }
    
    public Schelling(final long seed, final int width, final int height) {
        super(seed);
        this.neighborhood = 1;
        this.threshold = 3;
        this.redProbability = 0.4;
        this.blueProbability = 0.4;
        this.emptyProbability = 0.2;
        this.unavailableProbability = 0.0;
        this.emptySpaces = new Bag();
        this.gridWidth = width;
        this.gridHeight = height;
        this.createGrids();
    }
    
    protected void createGrids() {
        this.emptySpaces.clear();
        this.neighbors = new IntGrid2D(this.gridWidth, this.gridHeight, 0);
        final int[][] g = this.neighbors.field;
        for (int x = 0; x < this.gridWidth; ++x) {
            for (int y = 0; y < this.gridHeight; ++y) {
                final double d = this.random.nextDouble();
                if (d < this.redProbability) {
                    g[x][y] = 2;
                }
                else if (d < this.redProbability + this.blueProbability) {
                    g[x][y] = 3;
                }
                else if (d < this.redProbability + this.blueProbability + this.emptyProbability) {
                    g[x][y] = 0;
                    this.emptySpaces.add((Object)new Int2D(x, y));
                }
                else {
                    g[x][y] = 1;
                }
            }
        }
    }
    
    public void start() {
        super.start();
        this.createGrids();
        for (int x = 0; x < this.gridWidth; ++x) {
            for (int y = 0; y < this.gridHeight; ++y) {
                this.schedule.scheduleRepeating((Steppable)new Agent(x, y));
            }
        }
    }
    
    public static void main(final String[] args) {
        doLoop((Class)Schelling.class, args);
        System.exit(0);
    }
}
