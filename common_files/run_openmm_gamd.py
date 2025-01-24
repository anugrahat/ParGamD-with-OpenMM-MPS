#!/usr/bin/env python3
from openmm import *
from openmm.app import *
from openmm.unit import *
import numpy as np

class GaMDSimulation:
    def __init__(self, rst_file, prmtop_file, platform='CUDA'):
        self.rst_file = rst_file
        self.prmtop_file = prmtop_file
        self.platform_name = platform
        
    def setup_system(self):
        print("Setting up system from equilibrated structure...")
        # Load topology and coordinates
        self.prmtop = AmberPrmtopFile(self.prmtop_file)
        inpcrd = AmberInpcrdFile(self.rst_file)
        self.positions = inpcrd.positions
        
        # Create system
        print("Creating system...")
        self.system = self.prmtop.createSystem(
            nonbondedMethod=CutoffNonPeriodic,
            nonbondedCutoff=1.0*nanometers,
            constraints=HBonds
        )
        
        # Add thermostat
        print("Adding thermostat...")
        self.system.addForce(AndersenThermostat(300*kelvin, 1/picosecond))
        
    def create_gamd_integrator(self):
        """Create GaMD integrator with standard parameters"""
        print("Creating GaMD integrator...")
        timestep = 2.0*femtoseconds
        integrator = LangevinMiddleIntegrator(300*kelvin, 1/picosecond, timestep)
        
        # Add GaMD-specific variables
        integrator.addGlobalVariable("sigma0P", 6.0*kilocalories_per_mole)
        integrator.addGlobalVariable("sigma0D", 6.0*kilocalories_per_mole)
        integrator.addGlobalVariable("EthreshP", 0.0)
        integrator.addGlobalVariable("EthreshD", 0.0)
        
        return integrator
        
    def setup_simulation(self):
        """Setup simulation starting from RST file"""
        self.setup_system()
        self.integrator = self.create_gamd_integrator()
        
        # Setup platform
        print(f"Setting up {self.platform_name} platform...")
        self.platform = Platform.getPlatformByName(self.platform_name)
        properties = {'CudaPrecision': 'mixed'} if self.platform_name == 'CUDA' else {}
        
        # Create simulation
        print("Creating simulation object...")
        self.simulation = Simulation(
            self.prmtop.topology,
            self.system,
            self.integrator,
            self.platform,
            properties
        )
        
        # Set positions from RST
        print("Setting positions from RST file...")
        self.simulation.context.setPositions(self.positions)
        
        # Initialize velocities
        print("Initializing velocities...")
        self.simulation.context.setVelocitiesToTemperature(300*kelvin)
    
    def add_reporters(self, traj_file, log_file, report_interval=1000):
        print(f"Adding reporters (interval: {report_interval})...")
        self.simulation.reporters.append(DCDReporter(traj_file, report_interval))
        self.simulation.reporters.append(StateDataReporter(
            log_file, 
            report_interval,
            step=True,
            time=True,
            potentialEnergy=True,
            temperature=True,
            speed=True,
            totalSteps=500000,
            separator='\t'
        ))
    
    def run(self, steps=500000):
        print(f"Running production simulation for {steps} steps...")
        try:
            interval = 10000
            for i in range(0, steps, interval):
                current_steps = min(interval, steps - i)
                self.simulation.step(current_steps)
                state = self.simulation.context.getState(getEnergy=True)
                energy = state.getPotentialEnergy().value_in_unit(kilojoules_per_mole)
                print(f"Step {i}, Energy: {energy:.2f} kJ/mol")
                
            print("Simulation completed successfully!")
        except Exception as e:
            print(f"Error during simulation: {str(e)}")
            raise

def main():
    import argparse
    parser = argparse.ArgumentParser(description='Run GaMD from RST file')
    parser.add_argument('--rst', required=True, help='Input RST file')
    parser.add_argument('--prmtop', required=True, help='Topology file')
    parser.add_argument('--output', required=True, help='Output trajectory')
    parser.add_argument('--log', required=True, help='Log file')
    parser.add_argument('--platform', default='CUDA', 
                       choices=['CUDA', 'CPU', 'OpenCL', 'Reference'])
    args = parser.parse_args()
    
    print(f"OpenMM version: {Platform.getOpenMMVersion()}")
    print("Available platforms:")
    for i in range(Platform.getNumPlatforms()):
        print(f"  {Platform.getPlatform(i).getName()}")
        
    # Create and run simulation
    gamd = GaMDSimulation(args.rst, args.prmtop, args.platform)
    gamd.setup_simulation()
    gamd.add_reporters(args.output, args.log)
    gamd.run()

if __name__ == "__main__":
    main()