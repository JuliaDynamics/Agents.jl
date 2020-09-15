package sim.app.flockers;

import sim.engine.Steppable;
import sim.util.Bag;
import sim.util.Double2D;
import sim.field.continuous.Continuous2D;
import sim.engine.SimState;

public class FlockersBenchmark extends SimState
{
    private static final long serialVersionUID = 1L;
    public Continuous2D flockers;
    public double width;
    public double height;
    public int numFlockers;
    public double cohesion;
    public double avoidance;
    public double randomness;
    public double consistency;
    public double momentum;
    public double deadFlockerProbability;
    public double neighborhood;
    public double jump;

    public double getCohesion() {
        return this.cohesion;
    }

    public void setCohesion(final double val) {
        if (val >= 0.0) {
            this.cohesion = val;
        }
    }

    public double getAvoidance() {
        return this.avoidance;
    }

    public void setAvoidance(final double val) {
        if (val >= 0.0) {
            this.avoidance = val;
        }
    }

    public double getRandomness() {
        return this.randomness;
    }

    public void setRandomness(final double val) {
        if (val >= 0.0) {
            this.randomness = val;
        }
    }

    public double getConsistency() {
        return this.consistency;
    }

    public void setConsistency(final double val) {
        if (val >= 0.0) {
            this.consistency = val;
        }
    }

    public double getMomentum() {
        return this.momentum;
    }

    public void setMomentum(final double val) {
        if (val >= 0.0) {
            this.momentum = val;
        }
    }

    public int getNumFlockers() {
        return this.numFlockers;
    }

    public void setNumFlockers(final int val) {
        if (val >= 1) {
            this.numFlockers = val;
        }
    }

    public double getWidth() {
        return this.width;
    }

    public void setWidth(final double val) {
        if (val > 0.0) {
            this.width = val;
        }
    }

    public double getHeight() {
        return this.height;
    }

    public void setHeight(final double val) {
        if (val > 0.0) {
            this.height = val;
        }
    }

    public double getNeighborhood() {
        return this.neighborhood;
    }

    public void setNeighborhood(final double val) {
        if (val > 0.0) {
            this.neighborhood = val;
        }
    }

    public double getDeadFlockerProbability() {
        return this.deadFlockerProbability;
    }

    public void setDeadFlockerProbability(final double val) {
        if (val >= 0.0 && val <= 1.0) {
            this.deadFlockerProbability = val;
        }
    }

    public Double2D[] getLocations() {
        if (this.flockers == null) {
            return new Double2D[0];
        }
        final Bag b = this.flockers.getAllObjects();
        if (b == null) {
            return new Double2D[0];
        }
        final Double2D[] locs = new Double2D[b.numObjs];
        for (int i = 0; i < b.numObjs; ++i) {
            locs[i] = this.flockers.getObjectLocation(b.objs[i]);
        }
        return locs;
    }

    public double getMeanXLocation() {
        final Double2D[] locations = this.getLocations();
        double avg = 0.0;
        for (int i = 0; i < locations.length; ++i) {
            avg += locations[i].x;
        }
        if (locations.length > 0) {
            avg /= locations.length;
        }
        return avg;
    }

    public Double2D[] getInvertedLocations() {
        if (this.flockers == null) {
            return new Double2D[0];
        }
        final Bag b = this.flockers.getAllObjects();
        if (b == null) {
            return new Double2D[0];
        }
        final Double2D[] locs = new Double2D[b.numObjs];
        for (int i = 0; i < b.numObjs; ++i) {
            locs[i] = this.flockers.getObjectLocation(b.objs[i]);
            locs[i] = new Double2D(locs[i].y, locs[i].x);
        }
        return locs;
    }

    public FlockersBenchmark(final long seed) {
        super(seed);
        this.width = 100.0; //
        this.height = 100.0; //
        this.numFlockers = 100; //
        this.cohesion = 0.25; //
        this.avoidance = 4.0; //
        this.randomness = 1.0; //
        this.consistency = 0.01; //
        this.momentum = 1.0; //
        this.deadFlockerProbability = 0.0; //
        this.neighborhood = 5.0; //
        this.jump = 0.7;
    }

    public void start() {
        super.start();
        this.flockers = new Continuous2D(this.neighborhood / 1.5, this.width, this.height);
        //this.flockers = new Continuous2D(0.1, this.width, this.height); // For non-compartmental
        for (int x = 0; x < this.numFlockers; ++x) {
            final Double2D location = new Double2D(this.random.nextDouble() * this.width, this.random.nextDouble() * this.height);
            final Flocker flocker = new Flocker(location);
            if (this.random.nextBoolean(this.deadFlockerProbability)) {
                flocker.dead = true;
            }
            this.flockers.setObjectLocation((Object)flocker, location);
            flocker.flockers = this.flockers;
            flocker.theFlock = this;
            this.schedule.scheduleRepeating((Steppable)flocker);
        }
    }

    public static void main(final String[] args) {
        doLoop((Class)FlockersBenchmark.class, args);
        System.exit(0);
    }
}
