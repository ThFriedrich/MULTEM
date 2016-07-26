/**
 * This file is part of MULTEM.
 * Copyright 2016 Ivan Lobato <Ivanlh20@gmail.com>
 *
 * MULTEM is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * MULTEM is distributed in the hope that it will be useful, 
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with MULTEM. If not, see <http://www.gnu.org/licenses/>.
 */

#include "types.cuh"
#include "matlab_types.cuh"
#include "traits.cuh"
#include "stream.cuh"
#include "fft2.cuh"
#include "input_multislice.cuh"
#include "output_multislice.hpp"
#include "host_functions.hpp"
#include "device_functions.cuh"
#include "host_device_functions.cuh"
#include "propagator.cuh"

#include <mex.h>
#include "matlab_mex.cuh"

using mt::rmatrix_r;
using mt::rmatrix_c;

template<class TInput_Multislice>
void read_input_multislice(const mxArray *mx_input_multislice, TInput_Multislice &input_multislice, bool full =true)
{
	using value_type_r = mt::Value_type<TInput_Multislice>;

	input_multislice.precision = mx_get_scalar_field<mt::ePrecision>(mx_input_multislice, "precision");
	input_multislice.device = mx_get_scalar_field<mt::eDevice>(mx_input_multislice, "device"); 
	input_multislice.cpu_ncores = mx_get_scalar_field<int>(mx_input_multislice, "cpu_ncores"); 
	input_multislice.cpu_nthread = mx_get_scalar_field<int>(mx_input_multislice, "cpu_nthread"); 
	input_multislice.gpu_device = mx_get_scalar_field<int>(mx_input_multislice, "gpu_device"); 
	input_multislice.gpu_nstream = mx_get_scalar_field<int>(mx_input_multislice, "gpu_nstream"); 

	input_multislice.simulation_type = mt::eTEMST_PropRS;

	input_multislice.E_0 = mx_get_scalar_field<value_type_r>(mx_input_multislice, "E_0");
	input_multislice.theta = mx_get_scalar_field<value_type_r>(mx_input_multislice, "theta")*mt::c_deg_2_rad;
	input_multislice.phi = mx_get_scalar_field<value_type_r>(mx_input_multislice, "phi")*mt::c_deg_2_rad;

	bool bwl = true;
	bool pbc_xy = true;

	auto nx = mx_get_scalar_field<int>(mx_input_multislice, "nx");
	auto ny = mx_get_scalar_field<int>(mx_input_multislice, "ny");
	auto lx = mx_get_scalar_field<value_type_r>(mx_input_multislice, "lx");
	auto ly = mx_get_scalar_field<value_type_r>(mx_input_multislice, "ly");
	value_type_r dz = 0.25;

	input_multislice.grid.set_input_data(nx, ny, lx, ly, dz, bwl, pbc_xy);

	/****************************** Incident wave ********************************/
	auto iw_type = mx_get_scalar_field<mt::eIncident_Wave_Type>(mx_input_multislice, "iw_type");
	input_multislice.set_incident_wave_type(iw_type);

	if(input_multislice.is_user_define_wave() && full)
	{
		auto iw_psi = mx_get_matrix_field<rmatrix_c>(mx_input_multislice, "iw_psi");
		mt::Stream<mt::e_host> stream(input_multislice.cpu_nthread);
		mt::assign(stream, iw_psi, input_multislice.iw_psi);
	}

	input_multislice.obj_lens.f = mx_get_scalar_field<value_type_r>(mx_input_multislice, "obj_lens_f"); 									// defocus(Angstrom)
	input_multislice.obj_lens.set_input_data(input_multislice.E_0, input_multislice.grid);

	input_multislice.validate_parameters();
 }

void set_output_multislice(const mxArray *mx_input_multislice, mxArray *&mx_output_multislice, mt::Output_Multislice_Matlab &output_multislice)
{
	mt::Input_Multislice<double> input_multislice;
	read_input_multislice(mx_input_multislice, input_multislice, false);
	output_multislice.set_input_data(&input_multislice);

	const char *field_names_output_multislice[] = {"dx", "dy", "x", "y", "thickness", "psi"};
	int number_of_fields_output_multislice = 6;
	mwSize dims_output_multislice[2] = {1, 1};

	mx_output_multislice = mxCreateStructArray(2, dims_output_multislice, number_of_fields_output_multislice, field_names_output_multislice);

	mx_create_set_scalar_field<rmatrix_r>(mx_output_multislice, 0, "dx", output_multislice.dx);
	mx_create_set_scalar_field<rmatrix_r>(mx_output_multislice, 0, "dy", output_multislice.dy);
	mx_create_set_matrix_field<rmatrix_r>(mx_output_multislice, "x", 1, output_multislice.x.size(), output_multislice.x.data());
	mx_create_set_matrix_field<rmatrix_r>(mx_output_multislice, "y", 1, output_multislice.y.size(), output_multislice.y.data());
	mx_create_set_matrix_field<rmatrix_r>(mx_output_multislice, "thickness", 1, output_multislice.thickness.size(), output_multislice.thickness.data());
	output_multislice.psi_coh[0] = mx_create_matrix_field<rmatrix_c>(mx_output_multislice, "psi", output_multislice.ny, output_multislice.nx);
}

template<class T, mt::eDevice dev>
void il_propagate(const mxArray *mxB, mt::Output_Multislice_Matlab &output_multislice)
{
	mt::Input_Multislice<T> input_multislice;
	read_input_multislice(mxB, input_multislice);

	mt::Stream<dev> stream;
	mt::FFT2<T, dev> fft2;
	mt::Propagator<T, dev> propagator;

	stream.resize(input_multislice.nstream);
	fft2.create_plan_2d(input_multislice.grid.ny, input_multislice.grid.nx, input_multislice.nstream);
	propagator.set_input_data(&input_multislice, &stream, &fft2);

	T gx_0 = input_multislice.gx_0();
	T gy_0 = input_multislice.gy_0();

	propagator.propagate(mt::eS_Real, gx_0, gy_0, input_multislice.obj_lens.f, output_multislice);

	fft2.cleanup();
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
	mt::Output_Multislice_Matlab output_multislice;
	set_output_multislice(prhs[0], plhs[0], output_multislice);

	if(output_multislice.is_float_host())
	{
		il_propagate<float, mt::e_host>(prhs[0], output_multislice);
	}
	else if(output_multislice.is_double_host())
	{
		il_propagate<double, mt::e_host>(prhs[0], output_multislice);
	}
	if(output_multislice.is_float_device())
	{
		il_propagate<float, mt::e_device>(prhs[0], output_multislice);
	}
	else if(output_multislice.is_double_device())
	{
		il_propagate<double, mt::e_device>(prhs[0], output_multislice);
	}
}